import SwiftUI
import UIKit
import MapKit
import CoreLocation
import EventKit
import Speech
import AVFoundation
import UserNotifications

@main
struct IkkeGlemApp: App {
    @StateObject private var model = ReminderModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

struct Reminder: Identifiable, Codable {
    let id: UUID
    let title: String
    let appointment: Date
    let alert: Date
    var address: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var calendarEventID: String? = nil
}

struct ContentView: View {
    @ObservedObject var model: ReminderModel
    @State private var showCalendars = false
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("ForgetfulBackground").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }.ignoresSafeArea()
            Color.black.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("ikke glem by MP").font(.largeTitle.bold())
                Text("Ett trykk. Si det. Ferdig. · v1.9").foregroundStyle(.secondary)
                Button { showCalendars = true } label: { Label("Kalender", systemImage: "calendar.badge.plus") }.disabled(model.busy || model.listening)
                Button { model.tap() } label: {
                    ZStack {
                        Image("VoiceButton").resizable().scaledToFit().frame(height: 130)
                        if model.listening { ProgressView().tint(.white).scaleEffect(1.5) }
                    }.frame(maxWidth: .infinity).padding(14)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                .disabled(model.busy || model.listening)
                .accessibilityLabel(model.listening ? "Lytter" : "Snakk")
                Text(model.transcript).font(.title3).accessibilityLabel("Det du sa")
                Text(model.status).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.updatesFrequently)
                List {
                    ForEach(model.reminders.sorted { $0.appointment < $1.appointment }) { reminder in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reminder.title).font(.headline)
                            Text("Avtale: \(reminder.appointment.formatted(date: .abbreviated, time: .shortened))")
                            Text("Varsel: \(reminder.alert.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.yellow)
                            if let address = reminder.address {
                                Text(address).font(.subheadline)
                                Button { model.openMaps(reminder) } label: { Label("Åpne i Maps", systemImage: "map") }.buttonStyle(.borderless)
                            }
                        }.listRowBackground(Color(red: 0.025, green: 0.065, blue: 0.14).opacity(0.9))
                        .swipeActions { Button("Slett", role: .destructive) { model.remove(reminder) } }
                    }
                }.scrollContentBackground(.hidden).listStyle(.plain)
            }.padding()
        }.preferredColorScheme(.dark)
            .sheet(isPresented: $showCalendars) {
                NavigationStack {
                    List {
                        Section {
                            Button("Ikke lagre i kalender") { model.selectCalendar(nil); showCalendars = false }
                            ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                                Button {
                                    model.selectCalendar(calendar)
                                    showCalendars = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(calendar.title)
                                            Text(calendar.source.title).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if model.selectedCalendarID == calendar.calendarIdentifier { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } header: { Text("Velg kalender for automatisk lagring") }
                        Section {
                            Text(model.calendarStatus)
                            Text("Google-kontoen må være lagt til under iPhone-innstillinger → Apper → Kalender → Kalenderkontoer. Velg deretter kalenderen fra Google-kontoen her.")
                            Text("Avtaler lagres i den valgte kalenderen. Fanfaren kommer fra denne appen.")
                        }
                    }.navigationTitle("Kalender")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Ferdig") { showCalendars = false } } }
                        .task { await model.loadCalendars() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in model.interrupted() }
    }
}

@MainActor
final class ReminderModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var reminders: [Reminder] = []
    @Published var listening = false
    @Published var busy = false
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarID = ""
    @Published var calendarStatus = "Velg en kalender. Nye avtaler lagres automatisk der."
    @Published var transcript = ""
    @Published var status = "Si: Legen klokken åtte i morgen, minn meg på det 30 minutter før."
    private let calendarStore = EKEventStore()
    private let calendarKey = "ikke-glem-selected-calendar"
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var silence: Task<Void, Never>?
    private var limit: Task<Void, Never>?
    private var sessionID: UUID?
    private var hasTap = false
    private let storage = "ikke-glem-native-v1"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: storage),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) { reminders = saved }
        selectedCalendarID = UserDefaults.standard.string(forKey: calendarKey) ?? ""
        UNUserNotificationCenter.current().delegate = self
    }

    func tap() {
        guard !busy && !listening else { return }
        busy = true
        Task {
            defer { busy = false }
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            let microphone = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard speech && microphone else {
                status = "Tillat mikrofon og talegjenkjenning i Innstillinger → Ikke glem."
                return
            }
            do {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else {
                    status = "Tillat varsler i Innstillinger → Ikke glem, så kan jeg minne deg på avtalen."
                    return
                }
                try begin()
            } catch { stop(); status = "Kunne ikke starte: \(error.localizedDescription)" }
        }
    }

    private func begin() throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "nb-NO")), recognizer.isAvailable else {
            throw NSError(domain: "IkkeGlem", code: 1, userInfo: [NSLocalizedDescriptionKey: "Norsk talegjenkjenning er ikke tilgjengelig akkurat nå. Kontroller internett og prøv igjen."])
        }
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true, options: .notifyOthersOnDeactivation)
        let id = UUID()
        sessionID = id
        transcript = ""
        status = "Lytter på norsk …"
        let bufferRequest = SFSpeechAudioBufferRecognitionRequest()
        bufferRequest.shouldReportPartialResults = true
        bufferRequest.taskHint = .dictation
        request = bufferRequest
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw NSError(domain: "IkkeGlem", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mikrofonen er ikke tilgjengelig."])
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in bufferRequest.append(buffer) }
        hasTap = true
        recognition = recognizer.recognitionTask(with: bufferRequest) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let errorText = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == id else { return }
                if let text, !text.isEmpty {
                    self.transcript = text
                    self.silence?.cancel()
                    if final { self.finish() }
                    else {
                        self.silence = Task { [weak self] in
                            do { try await Task.sleep(nanoseconds: 1_800_000_000) } catch { return }
                            guard let self, self.sessionID == id else { return }
                            self.finish()
                        }
                    }
                } else if let errorText { self.stop(); self.status = "Talegjenkjenning feilet: \(errorText)" }
            }
        }
        engine.prepare()
        try engine.start()
        listening = true
        limit = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard let self, self.sessionID == id else { return }
            self.finish()
        }
    }

    private func finish() {
        let spoken = transcript
        stop()
        guard let spokenReminder = NorwegianDateParser.parseSpoken(spoken) else {
            status = "Jeg forstod ikke avtalen eller varseltiden. Prøv: Legen klokken åtte i morgen, minn meg på det 30 minutter før. Varseltiden må være i fremtiden."
            return
        }
        let parsed = spokenReminder.appointment
        busy = true
        Task {
            defer { busy = false }
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            guard pending.count < 60 else { status = "For mange aktive varsler. Slett en påminnelse først."; return }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { status = "Varsler er slått av. Tillat varsler i Innstillinger."; return }
            let alert = spokenReminder.alert
            guard alert > Date() else { status = "Varseltiden har allerede passert. Prøv igjen med en senere tid."; return }
            var reminder = Reminder(id: UUID(), title: parsed.title, appointment: parsed.date, alert: alert, address: spokenReminder.address)
            let content = UNMutableNotificationContent()
            content.title = "ikke glem by MP"
            content.body = "\(parsed.title) klokken \(parsed.date.formatted(date: .omitted, time: .shortened))"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("ikke-glem-fanfare.wav"))
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert)
            components.timeZone = .current
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger))
                let calendarResult = saveToCalendar(&reminder)
                reminders.append(reminder)
                persist()
                if let address = spokenReminder.address { resolveAddress(address, id: reminder.id) }
                status = "Lagret ✓ Varsel \(alert.formatted(date: .abbreviated, time: .shortened))." + calendarResult
                if spokenReminder.usedDefault { status += " Uten oppgitt varseltid varsles du ved avtalen." }
            } catch { status = "Kunne ikke lagre varselet: \(error.localizedDescription)" }
        }
    }

    private var calendarAccess: Bool {
        if #available(iOS 17.0, *) { return EKEventStore.authorizationStatus(for: .event) == .fullAccess }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }
    func loadCalendars() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) { granted = try await calendarStore.requestFullAccessToEvents() }
            else { granted = try await calendarStore.requestAccess(to: .event) }
            guard granted else {
                calendars = []
                calendarStatus = "Kalendertilgang er avslått. Du kan gi tilgang i Innstillinger → Apper → ikke glem by MP."
                return
            }
            calendars = calendarStore.calendars(for: .event).filter { $0.allowsContentModifications }.sorted { $0.source.title + $0.title < $1.source.title + $1.title }
            calendarStatus = calendars.isEmpty ? "Ingen skrivbar kalender er tilgjengelig. Legg til Google-kontoen i iPhone-innstillingene." : "Velg Google-kalenderen under riktig konto. Bare nye avtaler lagres."
        } catch { calendars = []; calendarStatus = "Kunne ikke hente kalendere: \(error.localizedDescription)" }
    }
    func selectCalendar(_ calendar: EKCalendar?) {
        selectedCalendarID = calendar?.calendarIdentifier ?? ""
        UserDefaults.standard.set(selectedCalendarID, forKey: calendarKey)
        calendarStatus = calendar.map { "Lagrer nye avtaler i \($0.title) · \($0.source.title)." } ?? "Automatisk kalenderlagring er slått av."
    }
    private func saveToCalendar(_ reminder: inout Reminder) -> String {
        guard !selectedCalendarID.isEmpty else { return "" }
        guard calendarAccess, let calendar = calendarStore.calendar(withIdentifier: selectedCalendarID), calendar.allowsContentModifications else {
            return " Kalenderen kunne ikke brukes; velg den på nytt under Kalender. App-varselet er lagret."
        }
        let event = EKEvent(eventStore: calendarStore)
        event.title = reminder.title
        event.startDate = reminder.appointment
        event.endDate = reminder.appointment.addingTimeInterval(1800)
        event.location = reminder.address
        event.calendar = calendar
        event.notes = "Lagt til av ikke glem by MP."
        event.alarms = []
        do {
            try calendarStore.save(event, span: .thisEvent)
            reminder.calendarEventID = event.eventIdentifier
            return " Lagt til i \(calendar.title)."
        } catch { return " Kalenderlagring feilet: \(error.localizedDescription). App-varselet er lagret." }
    }

    private func resolveAddress(_ address: String, id: UUID) {
        Task {
            do {
                let places = try await CLGeocoder().geocodeAddressString(address)
                guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
                // Keep ambiguous results as a Maps search instead of choosing an arbitrary location.
                guard places.count == 1, let location = places.first?.location else {
                    status += " Adressen er ikke entydig; Maps-knappen søker etter den."
                    return
                }
                reminders[index].latitude = location.coordinate.latitude
                reminders[index].longitude = location.coordinate.longitude
                persist()
            } catch {
                if reminders.contains(where: { $0.id == id }) { status += " Adressen er lagret; Maps-knappen kan søke etter den." }
            }
        }
    }

    func openMaps(_ reminder: Reminder) {
        if let latitude = reminder.latitude, let longitude = reminder.longitude {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
            item.name = reminder.address ?? reminder.title
            item.openInMaps()
        } else if let address = reminder.address {
            var components = URLComponents(string: "https://maps.apple.com/")!
            components.queryItems = [URLQueryItem(name: "q", value: address)]
            if let url = components.url { UIApplication.shared.open(url) }
        }
    }

    private func stop() {
        sessionID = nil
        silence?.cancel(); silence = nil
        limit?.cancel(); limit = nil
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        listening = false
    }
    func interrupted() { if listening { stop(); status = "Opptaket ble avbrutt. Trykk Snakk og prøv igjen." } }
    func remove(_ reminder: Reminder) {
        if let id = reminder.calendarEventID, calendarAccess, let event = calendarStore.event(withIdentifier: id) {
            do { try calendarStore.remove(event, span: .thisEvent) }
            catch { status = "Kalenderavtalen kunne ikke slettes: \(error.localizedDescription)" }
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminder.id.uuidString])
        reminders.removeAll { $0.id == reminder.id }; persist()
    }
    private func persist() { if let data = try? JSONEncoder().encode(reminders) { UserDefaults.standard.set(data, forKey: storage) } }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
}

