import SwiftUI
import UIKit
import MapKit
import CoreLocation
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
}

struct ContentView: View {
    @ObservedObject var model: ReminderModel
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.07, blue: 0.14).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("ikke glem by MP").font(.largeTitle.bold())
                Text("Ett trykk. Si det. Ferdig.").foregroundStyle(.secondary)
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
                        }.listRowBackground(Color.white.opacity(0.06))
                        .swipeActions { Button("Slett", role: .destructive) { model.remove(reminder) } }
                    }
                }.scrollContentBackground(.hidden).listStyle(.plain)
            }.padding()
        }.preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in model.interrupted() }
    }
}

@MainActor
final class ReminderModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var reminders: [Reminder] = []
    @Published var listening = false
    @Published var busy = false
    @Published var transcript = ""
    @Published var status = "Si: Legen klokken åtte i morgen, minn meg på det 30 minutter før."
    private let sound = SpeechNotificationSound()
    private var spokenSoundReady = false
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
                spokenSoundReady = await sound.prepare()
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
            let reminder = Reminder(id: UUID(), title: parsed.title, appointment: parsed.date, alert: alert, address: spokenReminder.address)
            let content = UNMutableNotificationContent()
            content.title = "ikke glem by MP"
            content.body = "\(parsed.title) klokken \(parsed.date.formatted(date: .omitted, time: .shortened))"
            content.sound = spokenSoundReady ? UNNotificationSound(named: UNNotificationSoundName("ikke-glem.caf")) : .default
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert)
            components.timeZone = .current
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger))
                reminders.append(reminder)
                persist()
                if let address = spokenReminder.address { resolveAddress(address, id: reminder.id) }
                status = "Lagret ✓ Varsel \(alert.formatted(date: .abbreviated, time: .shortened))."
                if !spokenSoundReady { status += " Norsk talelyd er ikke tilgjengelig; bruker vanlig varseltone." }
                if spokenReminder.usedDefault { status += " Uten oppgitt varseltid brukes én time før, eller straks hvis den tiden er passert." }
            } catch { status = "Kunne ikke lagre varselet: \(error.localizedDescription)" }
        }
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminder.id.uuidString])
        reminders.removeAll { $0.id == reminder.id }; persist()
    }
    private func persist() { if let data = try? JSONEncoder().encode(reminders) { UserDefaults.standard.set(data, forKey: storage) } }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
}


@MainActor
private final class SpeechNotificationSound {
    private let synthesizer = AVSpeechSynthesizer()
    private var writer: AVAudioFile?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timeout: Task<Void, Never>?
    private var url: URL?

    func prepare() async -> Bool {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return false }
        let directory = library.appendingPathComponent("Sounds", isDirectory: true)
        let destination = directory.appendingPathComponent("ikke-glem.caf")
        url = destination
        if validSound(destination) { return true }
        guard let voice = AVSpeechSynthesisVoice(language: "nb-NO") else { return false }
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) } catch { return false }
        let utterance = AVSpeechUtterance(string: "Ikke glem!")
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.usesApplicationAudioSession = false
        return await withCheckedContinuation { completion in
            continuation = completion
            timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
                self?.finish(false)
            }
            synthesizer.write(utterance) { [weak self] buffer in
                DispatchQueue.main.async {
                    guard let self, self.continuation != nil, let pcm = buffer as? AVAudioPCMBuffer else { return }
                    if pcm.frameLength == 0 {
                        self.writer = nil
                        self.finish(self.validSound(destination))
                        return
                    }
                    do {
                        if self.writer == nil {
                            let settings: [String: Any] = [
                                AVFormatIDKey: kAudioFormatLinearPCM,
                                AVSampleRateKey: pcm.format.sampleRate,
                                AVNumberOfChannelsKey: pcm.format.channelCount,
                                AVLinearPCMBitDepthKey: 16,
                                AVLinearPCMIsFloatKey: false,
                                AVLinearPCMIsBigEndianKey: false
                            ]
                            self.writer = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
                        }
                        try self.writer?.write(from: pcm)
                    } catch { self.finish(false) }
                }
            }
        }
    }

    private func validSound(_ url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return false }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        return duration > 0 && duration < 30
    }
    private func finish(_ success: Bool) {
        guard let completion = continuation else { return }
        continuation = nil
        timeout?.cancel(); timeout = nil
        writer = nil
        if !success {
            synthesizer.stopSpeaking(at: .immediate)
            if let url { try? FileManager.default.removeItem(at: url) }
        }
        completion.resume(returning: success)
    }
}
