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

struct FeedbackSnapshot: Hashable {
    let transcript: String
    let status: String
    let listening: Bool
    let busy: Bool
    let reminderListVisible: Bool
    let presentationRevision: Int
}

struct ContentView: View {
    @ObservedObject var model: ReminderModel
    @State private var showCalendars = false
    @State private var pendingCalendarReminder: UUID?
    @State private var showHelp = false
    @State private var writtenReminder = ""
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("ForgetfulBackground").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }.ignoresSafeArea()
            Color.black.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(model.ui("Ett trykk. Si det. Ferdig.")).foregroundStyle(.secondary)
                Picker(model.ui("Språk"), selection: $model.language) {
                    Text("Norsk").tag("nb")
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                }.pickerStyle(.segmented).disabled(model.busy || model.listening)
                Button { showHelp = true } label: { Label(model.ui("Hjelp og personvern"), systemImage: "info.circle") }
                Button { pendingCalendarReminder = nil; showCalendars = true } label: { Label(model.ui("Kalender"), systemImage: "calendar.badge.plus") }.disabled(model.busy || model.listening)
                Button { model.tap() } label: {
                    ZStack {
                        Image("VoiceButton").resizable().scaledToFit().frame(height: 130)
                        if model.listening { ProgressView().tint(.white).scaleEffect(1.5) }
                    }.frame(maxWidth: .infinity).padding(14)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                .disabled(model.busy || model.listening)
                .accessibilityLabel(model.ui(model.listening ? "Lytter" : "Snakk"))
                Text(model.ui("Ikke si sensitive opplysninger som passord, kontonummer eller kortnummer."))
                    .font(.footnote).foregroundStyle(.yellow).multilineTextAlignment(.center)
                if !model.transcript.isEmpty {
                    Text(model.transcript).font(.title3).accessibilityLabel(model.language == "de" ? "Das hast du gesagt" : model.language == "en" ? "What you said" : "Det du sa")
                }
                if !model.status.isEmpty {
                    Text(model.ui(model.status)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                Button { model.showReminders() } label: {
                    Label(model.ui("Mine påminnelser"), systemImage: "list.bullet")
                }.disabled(model.busy || model.listening)
                if model.reminderListVisible {
                List {
                    ForEach(model.reminders.sorted { $0.appointment < $1.appointment }) { reminder in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reminder.title).font(.headline)
                            Text(model.ui("Avtale: ") + model.dateText(reminder.appointment))
                            Text(model.ui("Varsel: ") + model.dateText(reminder.alert)).foregroundStyle(.yellow)
                            if reminder.calendarEventID == nil {
                                Button {
                                    if model.selectedCalendarID.isEmpty {
                                        pendingCalendarReminder = reminder.id
                                        showCalendars = true
                                    } else { model.addToCalendar(reminder.id) }
                                } label: { Label(model.ui("Legg i kalender"), systemImage: "calendar.badge.plus") }
                                    .buttonStyle(.borderless).disabled(model.busy || model.listening)
                            } else {
                                Label(model.ui("Lagt i kalender"), systemImage: "calendar.badge.checkmark").font(.caption).foregroundStyle(.secondary)
                            }
                            if let address = reminder.address {
                                Text(address).font(.subheadline)
                                Button { model.openMaps(reminder) } label: { Label(model.ui("Åpne i Maps"), systemImage: "map") }.buttonStyle(.borderless)
                            }
                        }.listRowBackground(Color(red: 0.025, green: 0.065, blue: 0.14).opacity(0.9))
                        .swipeActions { Button(model.ui("Slett"), role: .destructive) { model.remove(reminder) } }
                    }
                }.scrollContentBackground(.hidden).listStyle(.plain)
                } else { Spacer(minLength: 0) }
            }.padding()
        }.preferredColorScheme(.dark)
            .environment(\.locale, model.displayLocale)
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    Form {
                        Section(model.ui("Slik bruker du appen")) {
                            Text(model.ui("Trykk på den grønne knappen og si en påminnelse på norsk. Den lagres etter en kort pause."))
                            Text(model.ui("Nøkkel ligger i skapet, minner meg 655 → neste klokken 06:55."))
                            Text(model.ui("Legen klokken 18 i dag, minn meg klokken 17:41 → avtale 18:00, varsel 17:41."))
                            Text(model.ui("Minn meg om ti minutter → varsel om ti minutter."))
                            Text(model.ui("Uten egen varseltid kommer varselet ved avtalen. Kontroller alltid tiden som vises etter lagring."))
                            Text(model.ui("Påminnelser lagres bare i appen. Trykk «Legg i kalender» på en påminnelse hvis du også vil ha den i kalenderen."))
                        }
                        Section(model.ui("Skriv i stedet")) {
                            TextField(model.ui("Påminnelse og tidspunkt"), text: $writtenReminder, axis: .vertical)
                                .autocorrectionDisabled()
                            Button(model.ui("Lagre påminnelse")) { model.saveWritten(writtenReminder); writtenReminder = ""; showHelp = false }
                                .disabled(writtenReminder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy || model.listening)
                        }
                        Section(model.ui("Varsler")) {
                            Text(model.ui("iPhone planlegger lokale varsler også når appen er lukket. Lyd følger iPhone-innstillingene for lyd, Fokus og varsler. Dette er ikke en kritisk alarm."))
                            Button(model.ui("Åpne iPhone-innstillinger")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        Section(model.ui("Personvern")) {
                            Text(model.ui("Påminnelser lagres på iPhone. Appen lagrer ikke lydopptak og har ingen reklame eller sporing. Apples talegjenkjenning kan behandle lyd på Apples servere hvis lokal talegjenkjenning ikke er tilgjengelig."))
                            Text(model.ui("Ikke si sensitive opplysninger som passord, kontonummer eller kortnummer."))
                            Link(model.ui("Personvernerklæring"), destination: URL(string: "https://mayos950-sketch.github.io/ikke-glem/privacy.html")!)
                            Link(model.ui("Brukerstøtte"), destination: URL(string: "https://mayos950-sketch.github.io/ikke-glem/support.html")!)
                        }
                    }.navigationTitle(model.ui("Hjelp og personvern"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(model.ui("Ferdig")) { showHelp = false } } }
                }
            }
            .sheet(isPresented: $showCalendars, onDismiss: { pendingCalendarReminder = nil }) {
                NavigationStack {
                    List {
                        Section {
                            Button(model.ui("Ikke lagre i kalender")) { model.selectCalendar(nil); pendingCalendarReminder = nil; showCalendars = false }
                            ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                                Button {
                                    model.selectCalendar(calendar)
                                    if let id = pendingCalendarReminder { model.addToCalendar(id) }
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
                        } header: { Text(model.ui("Velg kalender når du vil legge til en avtale")) }
                        Section {
                            Text(model.ui(model.calendarStatus))
                            Text(model.ui("Google-kontoen må være lagt til under iPhone-innstillinger → Apper → Kalender → Kalenderkontoer. Velg deretter kalenderen fra Google-kontoen her."))
                            Text(model.ui("Ingen avtaler legges til automatisk. Trykk «Legg i kalender» på de påminnelsene du vil ha der. Fanfaren kommer fra denne appen."))
                        }
                    }.navigationTitle(model.ui("Kalender"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(model.ui("Ferdig")) { showCalendars = false } } }
                        .task { await model.loadCalendars() }
                }
            }
            .task(id: model.feedbackSnapshot) {
                let snapshot = model.feedbackSnapshot
                guard !snapshot.listening && !snapshot.busy,
                      !snapshot.transcript.isEmpty || !snapshot.status.isEmpty || snapshot.reminderListVisible else { return }
                do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                guard !Task.isCancelled, model.feedbackSnapshot == snapshot else { return }
                model.clearFeedback()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in model.interrupted() }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--screenshots-help") { showHelp = true }
                #endif
            }
    }
}

@MainActor
final class ReminderModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var language = UserDefaults.standard.string(forKey: "ikke-glem-language") ?? "nb" {
        didSet { UserDefaults.standard.set(language, forKey: "ikke-glem-language") }
    }
    var speechLocale: String { language == "de" ? "de-DE" : language == "en" ? "en-GB" : "nb-NO" }
    var displayLocale: Locale { Locale(identifier: speechLocale) }
    func ui(_ text: String) -> String { AppLanguage.translate(text, language: language) }
    func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(displayLocale).day().month().year().hour().minute())
    }
    func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(displayLocale).hour().minute())
    }

    @Published var reminderListVisible = true
    @Published private var presentationRevision = 0
    @Published var reminders: [Reminder] = []
    @Published var listening = false
    @Published var busy = false
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarID = ""
    @Published var calendarStatus = "Du velger selv hvilke påminnelser som legges i kalenderen."
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshots") {
            let calendar = Calendar.current
            let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: Date())!)!
            reminders = [
                Reminder(id: UUID(), title: "Legen", appointment: morning, alert: morning.addingTimeInterval(-1800)),
                Reminder(id: UUID(), title: "Nøkkel ligger i skapet", appointment: morning.addingTimeInterval(-3900), alert: morning.addingTimeInterval(-3900))
            ]
            status = "Lagret ✓ Du blir minnet på tidspunktet du sier."
        }
        #endif
    }

    var feedbackSnapshot: FeedbackSnapshot {
        FeedbackSnapshot(transcript: transcript, status: status, listening: listening, busy: busy, reminderListVisible: reminderListVisible, presentationRevision: presentationRevision)
    }

    func showReminders() {
        reminderListVisible = true
        presentationRevision += 1
    }

    func clearFeedback() {
        guard !listening && !busy else { return }
        transcript = ""
        status = ""
        reminderListVisible = false
    }

    func saveWritten(_ text: String) {
        guard !busy && !listening else { return }
        busy = true
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                guard allowed else { busy = false; status = "Tillat varsler i iPhone-innstillingene."; return }
                transcript = text
                busy = false
                finish()
            } catch { busy = false; status = "Kunne ikke be om varsler: \(error.localizedDescription)" }
        }
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
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: speechLocale)), recognizer.isAvailable else {
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
        bufferRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
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
                            do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
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
        guard let spokenReminder = NorwegianDateParser.parseSpoken(spoken, language: language) else {
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
            let reminder = Reminder(id: UUID(), title: parsed.title == "Påminnelse" ? ui(parsed.title) : parsed.title, appointment: parsed.date, alert: alert, address: spokenReminder.address)
            let content = UNMutableNotificationContent()
            content.title = "ikke glem by MP"
            content.body = "\(reminder.title) \(ui("klokken")) \(timeText(parsed.date))"
            content.sound = Bundle.main.url(forResource: "ikke-glem-fanfare", withExtension: "wav") == nil
                ? .default
                : UNNotificationSound(named: UNNotificationSoundName("ikke-glem-fanfare.wav"))
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert)
            components.timeZone = .current
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger))
                reminders.append(reminder)
                reminderListVisible = true
                persist()
                if let address = spokenReminder.address { resolveAddress(address, id: reminder.id) }
                status = "Lagret ✓ Varsel \(dateText(alert))."
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
            calendarStatus = calendars.isEmpty ? "Ingen skrivbar kalender er tilgjengelig. Legg til Google-kontoen i iPhone-innstillingene." : "Velg ønsket kalender. Bruk «Legg i kalender» på hver påminnelse."
        } catch { calendars = []; calendarStatus = "Kunne ikke hente kalendere: \(error.localizedDescription)" }
    }
    func selectCalendar(_ calendar: EKCalendar?) {
        selectedCalendarID = calendar?.calendarIdentifier ?? ""
        UserDefaults.standard.set(selectedCalendarID, forKey: calendarKey)
        calendarStatus = calendar.map { "Valgt: \($0.title) · \($0.source.title). Du legger til hver avtale selv." } ?? "Ingen kalender er valgt. Påminnelser lagres fortsatt i appen."
    }
    func addToCalendar(_ id: UUID) {
        guard !busy && !listening else { return }
        guard let reminder = reminders.first(where: { $0.id == id }), reminder.calendarEventID == nil else { return }
        guard !selectedCalendarID.isEmpty else {
            status = "Velg en kalender først, og trykk «Legg i kalender» på påminnelsen."
            return
        }
        busy = true
        Task {
            defer { busy = false }
            if !calendarAccess { await loadCalendars() }
            guard calendarAccess else { status = calendarStatus; return }
            guard let index = reminders.firstIndex(where: { $0.id == id }),
                  reminders[index].calendarEventID == nil else { return }
            var reminder = reminders[index]
            let result = saveToCalendar(&reminder)
            reminders[index] = reminder
            persist()
            status = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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
        event.notes = ui("Lagt til av ikke glem by MP.")
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



enum AppLanguage {
    static let labels: [String: [String]] = [
        "Mine påminnelser": ["Meine Erinnerungen", "My reminders"],
        "Språk": ["Sprache", "Language"],
        "klokken": ["um", "at"],
        "Lagt til av ikke glem by MP.": ["Hinzugefügt von ikke glem by MP.", "Added by ikke glem by MP."],
        "Ett trykk. Si det. Ferdig.": ["Einmal tippen. Sprechen. Fertig.", "One tap. Speak. Done."],
        "Hjelp og personvern": ["Hilfe und Datenschutz", "Help and privacy"],
        "Kalender": ["Kalender", "Calendar"],
        "Legg i kalender": ["In Kalender übernehmen", "Add to calendar"],
        "Lagt i kalender": ["Im Kalender gespeichert", "Added to calendar"],
        "Avtale: ": ["Termin: ", "Appointment: "],
        "Varsel: ": ["Erinnerung: ", "Reminder: "],
        "Ikke si sensitive opplysninger som passord, kontonummer eller kortnummer.": ["Sprich keine sensiblen Angaben wie Passwörter, Konto- oder Kartennummern ein.", "Do not speak sensitive information such as passwords, bank account or card numbers."],
        "Slik bruker du appen": ["So benutzt du die App", "How to use the app"],
        "Trykk på den grønne knappen og si en påminnelse på norsk. Den lagres etter en kort pause.": ["Tippe auf den grünen Button und sprich eine Erinnerung auf Deutsch. Sie wird nach einer kurzen Pause gespeichert.", "Tap the green button and speak a reminder in English. It is saved after a short pause."],
        "Nøkkel ligger i skapet, minner meg 655 → neste klokken 06:55.": ["Der Schlüssel liegt im Schrank, erinnere mich um 655 → nächstes 06:55.", "The key is in the cupboard, remind me at 655 → next 06:55."],
        "Legen klokken 18 i dag, minn meg klokken 17:41 → avtale 18:00, varsel 17:41.": ["Arzt heute um 18 Uhr, erinnere mich um 17:41 → Termin 18:00, Erinnerung 17:41.", "Doctor today at 18:00, remind me at 17:41 → appointment 18:00, reminder 17:41."],
        "Minn meg om ti minutter → varsel om ti minutter.": ["Erinnere mich in zehn Minuten → Erinnerung in zehn Minuten.", "Remind me in ten minutes → reminder in ten minutes."],
        "Uten egen varseltid kommer varselet ved avtalen. Kontroller alltid tiden som vises etter lagring.": ["Ohne eigene Erinnerungszeit erfolgt die Erinnerung zum Termin. Prüfe die angezeigte Zeit nach dem Speichern.", "Without a separate reminder time, you are reminded at the appointment. Check the displayed time after saving."],
        "Påminnelser lagres bare i appen. Trykk «Legg i kalender» på en påminnelse hvis du også vil ha den i kalenderen.": ["Erinnerungen werden nur in der App gespeichert. Tippe auf „In Kalender übernehmen“, wenn du auch einen Kalendertermin möchtest.", "Reminders are saved only in the app. Tap “Add to calendar” if you also want a calendar event."],
        "Skriv i stedet": ["Stattdessen schreiben", "Type instead"],
        "Påminnelse og tidspunkt": ["Erinnerung und Zeitpunkt", "Reminder and time"],
        "Lagre påminnelse": ["Erinnerung speichern", "Save reminder"],
        "Varsler": ["Mitteilungen", "Notifications"],
        "iPhone planlegger lokale varsler også når appen er lukket. Lyd følger iPhone-innstillingene for lyd, Fokus og varsler. Dette er ikke en kritisk alarm.": ["Das iPhone plant Mitteilungen auch bei geschlossener App. Der Ton folgt den Einstellungen für Lautstärke, Fokus und Mitteilungen. Dies ist kein kritischer Alarm.", "iPhone schedules local notifications even when the app is closed. Sound follows iPhone sound, Focus and notification settings. This is not a critical alarm."],
        "Åpne iPhone-innstillinger": ["iPhone-Einstellungen öffnen", "Open iPhone settings"],
        "Personvern": ["Datenschutz", "Privacy"],
        "Påminnelser lagres på iPhone. Appen lagrer ikke lydopptak og har ingen reklame eller sporing. Apples talegjenkjenning kan behandle lyd på Apples servere hvis lokal talegjenkjenning ikke er tilgjengelig.": ["Erinnerungen werden auf dem iPhone gespeichert. Die App speichert keine Tonaufnahmen und enthält keine Werbung oder Tracking. Apples Spracherkennung kann Audio auf Apple-Servern verarbeiten, wenn lokale Erkennung nicht verfügbar ist.", "Reminders are stored on iPhone. The app does not store audio recordings and has no advertising or tracking. Apple speech recognition may process audio on Apple servers when on-device recognition is unavailable."],
        "Personvernerklæring": ["Datenschutzerklärung", "Privacy policy"],
        "Brukerstøtte": ["Support", "Support"],
        "Ferdig": ["Fertig", "Done"],
        "Slett": ["Löschen", "Delete"],
        "Ikke lagre i kalender": ["Nicht im Kalender speichern", "Do not save to calendar"],
        "Velg kalender når du vil legge til en avtale": ["Kalender für den Termin wählen", "Choose the calendar for your event"],
        "Google-kontoen må være lagt til under iPhone-innstillinger → Apper → Kalender → Kalenderkontoer. Velg deretter kalenderen fra Google-kontoen her.": ["Das Google-Konto muss in iPhone-Einstellungen → Apps → Kalender → Kalenderaccounts eingerichtet sein. Wähle danach hier den Kalender des Google-Kontos.", "Add the Google account in iPhone Settings → Apps → Calendar → Calendar Accounts, then select its calendar here."],
        "Ingen avtaler legges til automatisk. Trykk «Legg i kalender» på de påminnelsene du vil ha der. Fanfaren kommer fra denne appen.": ["Es werden keine Termine automatisch eingetragen. Tippe bei den gewünschten Erinnerungen auf „In Kalender übernehmen“. Die Fanfare kommt von dieser App.", "No events are added automatically. Tap “Add to calendar” on the reminders you want there. The fanfare comes from this app."],
        "Åpne i Maps": ["In Maps öffnen", "Open in Maps"],
        "Lytter": ["Hört zu", "Listening"],
        "Snakk": ["Sprechen", "Speak"],
        "Du velger selv hvilke påminnelser som legges i kalenderen.": ["Du entscheidest, welche Erinnerungen in den Kalender kommen.", "You decide which reminders are added to the calendar."],
        "Si: Legen klokken åtte i morgen, minn meg på det 30 minutter før.": ["Sag: Arzt morgen um acht, erinnere mich 30 Minuten vorher.", "Say: Doctor tomorrow at eight, remind me 30 minutes before."],
        "Tillat varsler i iPhone-innstillingene.": ["Erlaube Mitteilungen in den iPhone-Einstellungen.", "Allow notifications in iPhone settings."],
        "Tillat mikrofon og talegjenkjenning i Innstillinger → Ikke glem.": ["Erlaube Mikrofon und Spracherkennung in Einstellungen → Ikke glem.", "Allow microphone and speech recognition in Settings → Ikke glem."],
        "Tillat varsler i Innstillinger → Ikke glem, så kan jeg minne deg på avtalen.": ["Erlaube Mitteilungen in Einstellungen → Ikke glem, damit ich dich erinnern kann.", "Allow notifications in Settings → Ikke glem so I can remind you."],
        "Norsk talegjenkjenning er ikke tilgjengelig akkurat nå. Kontroller internett og prøv igjen.": ["Spracherkennung ist gerade nicht verfügbar. Prüfe das Internet und versuche es erneut.", "Speech recognition is unavailable right now. Check the internet and try again."],
        "Mikrofonen er ikke tilgjengelig.": ["Das Mikrofon ist nicht verfügbar.", "The microphone is unavailable."],
        "Lytter på norsk …": ["Hört auf Deutsch zu …", "Listening in English …"],
        "Jeg forstod ikke avtalen eller varseltiden. Prøv: Legen klokken åtte i morgen, minn meg på det 30 minutter før. Varseltiden må være i fremtiden.": ["Ich habe Termin oder Erinnerungszeit nicht verstanden. Versuche: Arzt morgen um acht, erinnere mich 30 Minuten vorher. Die Erinnerung muss in der Zukunft liegen.", "I could not understand the appointment or reminder time. Try: Doctor tomorrow at eight, remind me 30 minutes before. The reminder must be in the future."],
        "For mange aktive varsler. Slett en påminnelse først.": ["Zu viele aktive Erinnerungen. Lösche zuerst eine Erinnerung.", "Too many active reminders. Delete a reminder first."],
        "Varsler er slått av. Tillat varsler i Innstillinger.": ["Mitteilungen sind ausgeschaltet. Erlaube sie in den Einstellungen.", "Notifications are off. Allow them in Settings."],
        "Varseltiden har allerede passert. Prøv igjen med en senere tid.": ["Die Erinnerungszeit ist vorbei. Versuche eine spätere Zeit.", "The reminder time has passed. Try a later time."],
        "Kalendertilgang er avslått. Du kan gi tilgang i Innstillinger → Apper → ikke glem by MP.": ["Kalenderzugriff wurde abgelehnt. Erlaube ihn in Einstellungen → Apps → ikke glem by MP.", "Calendar access was denied. Allow it in Settings → Apps → ikke glem by MP."],
        "Ingen skrivbar kalender er tilgjengelig. Legg til Google-kontoen i iPhone-innstillingene.": ["Kein beschreibbarer Kalender verfügbar. Richte einen Kalenderaccount in den iPhone-Einstellungen ein.", "No writable calendar is available. Add a calendar account in iPhone settings."],
        "Velg ønsket kalender. Bruk «Legg i kalender» på hver påminnelse.": ["Wähle den Kalender. Nutze „In Kalender übernehmen“ bei jeder gewünschten Erinnerung.", "Choose a calendar. Use “Add to calendar” on each reminder you want to add."],
        "Ingen kalender er valgt. Påminnelser lagres fortsatt i appen.": ["Kein Kalender gewählt. Erinnerungen werden weiterhin in der App gespeichert.", "No calendar is selected. Reminders are still saved in the app."],
        "Velg en kalender først, og trykk «Legg i kalender» på påminnelsen.": ["Wähle zuerst einen Kalender und tippe dann bei der Erinnerung auf „In Kalender übernehmen“.", "Choose a calendar first, then tap “Add to calendar” on the reminder."],
        " Kalenderen kunne ikke brukes; velg den på nytt under Kalender. App-varselet er lagret.": [" Der Kalender ist nicht verfügbar; wähle ihn unter Kalender erneut. Die App-Erinnerung ist gespeichert.", " The calendar is unavailable; select it again under Calendar. The app reminder is saved."],
        "Adressen er ikke entydig; Maps-knappen søker etter den.": ["Die Adresse ist nicht eindeutig; Maps sucht danach.", "The address is ambiguous; the Maps button will search for it."],
        "Adressen er lagret; Maps-knappen kan søke etter den.": ["Die Adresse ist gespeichert; Maps kann danach suchen.", "The address is saved; the Maps button can search for it."],
        "Opptaket ble avbrutt. Trykk Snakk og prøv igjen.": ["Die Aufnahme wurde unterbrochen. Tippe auf Sprechen und versuche es erneut.", "Recording was interrupted. Tap Speak and try again."],
        "Påminnelse": ["Erinnerung", "Reminder"]
    ]
    static let fragments: [(String, [String])] = [
        ("Kunne ikke be om varsler: ", ["Mitteilungen konnten nicht angefragt werden: ", "Could not request notifications: "]),
        ("Kunne ikke starte: ", ["Start fehlgeschlagen: ", "Could not start: "]),
        ("Talegjenkjenning feilet: ", ["Spracherkennung fehlgeschlagen: ", "Speech recognition failed: "]),
        ("Lagret ✓ Varsel ", ["Gespeichert ✓ Erinnerung ", "Saved ✓ Reminder "]),
        (" Uten oppgitt varseltid varsles du ved avtalen.", [" Ohne eigene Erinnerungszeit erfolgt die Erinnerung zum Termin.", " Without a separate reminder time, you are reminded at the appointment."]),
        ("Kunne ikke lagre varselet: ", ["Erinnerung konnte nicht gespeichert werden: ", "Could not save reminder: "]),
        ("Kunne ikke hente kalendere: ", ["Kalender konnten nicht geladen werden: ", "Could not load calendars: "]),
        ("Valgt: ", ["Gewählt: ", "Selected: "]),
        (". Du legger til hver avtale selv.", [". Du fügst jeden Termin selbst hinzu.", ". You add each event yourself."]),
        ("Lagt til i ", ["Im Kalender gespeichert: ", "Added to "]),
        ("Kalenderlagring feilet: ", ["Kalenderspeicherung fehlgeschlagen: ", "Calendar saving failed: "]),
        (". App-varselet er lagret.", [". Die App-Erinnerung ist gespeichert.", ". The app reminder is saved."]),
        ("Kalenderavtalen kunne ikke slettes: ", ["Kalendertermin konnte nicht gelöscht werden: ", "Could not delete calendar event: "]),
        ("Avtale: ", ["Termin: ", "Appointment: "]),
        ("Varsel: ", ["Erinnerung: ", "Reminder: "])
    ]
    static func translate(_ text: String, language: String) -> String {
        guard language == "de" || language == "en" else { return text }
        let index = language == "de" ? 0 : 1
        if let translated = labels[text] { return translated[index] }
        var result = text
        for (source, translations) in fragments { result = result.replacingOccurrences(of: source, with: translations[index]) }
        return result
    }
}
