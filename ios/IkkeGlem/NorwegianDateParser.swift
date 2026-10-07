import Foundation

enum NorwegianDateParser {
    static func splitAddress(_ input: String) -> (text: String, address: String?) {
        let pattern = #"\b(?:på adressen|adressen er|adresse|adressen)\s*[:,-]?\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range, in: input) else { return (input, nil) }
        let address = String(input[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !address.isEmpty else { return (input, nil) }
        return (String(input[..<range.lowerBound]), address)
    }
    struct SpokenReminder {
        let appointment: Parsed
        let alert: Date
        let address: String?
        let usedDefault: Bool
    }
    static func parseSpoken(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> SpokenReminder? {
        let marker = #"\b(?:minn(?:e)? meg(?: på det)?|minner meg(?: på det)?|varsle meg|påminn meg(?: på det)?)\s+"#
        let regex = try? NSRegularExpression(pattern: marker, options: .caseInsensitive)
        let match = regex?.firstMatch(in: input, range: NSRange(input.startIndex..., in: input))
        let range = match.flatMap { Range($0.range, in: input) }
        // A command that begins with Minn meg is a direct reminder, not an advance warning.
        if let range, input[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let direct = splitAddress(String(input[range.upperBound...]))
            guard let parsed = parse(direct.text, now: now, calendar: calendar), parsed.date > now else { return nil }
            return SpokenReminder(appointment: parsed, alert: parsed.date, address: direct.address, usedDefault: false)
        }
        if range == nil, let bare = parse(input, now: now, calendar: calendar), (bare.title == "Påminnelse" || input.lowercased().range(of: #"\bom\s+"#, options: .regularExpression) != nil), bare.date > now {
            return SpokenReminder(appointment: bare, alert: bare.date, address: nil, usedDefault: false)
        }
        let appointmentText = range.map { String(input[..<$0.lowerBound]) } ?? input
        let alarmText = range.map { String(input[$0.upperBound...]) }
        let main = splitAddress(appointmentText)
        let alarmPart = alarmText.map { splitAddress($0) }
        guard let appointment = parse(main.text, now: now, calendar: calendar), appointment.date > now else { return nil }
        let address = main.address ?? alarmPart?.address
        guard let alarm = alarmPart?.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) else {
            return SpokenReminder(appointment: appointment, alert: max(appointment.date.addingTimeInterval(-3600), now.addingTimeInterval(5)), address: address, usedDefault: true)
        }
        let requested: Date
        if alarm == "ved avtalen" || alarm == "på slaget" || alarm == "da" {
            requested = appointment.date
        } else if alarm == "en halvtime før" || alarm == "halvtime før" {
            requested = appointment.date.addingTimeInterval(-1800)
        } else if let expression = try? NSRegularExpression(pattern: #"^(\d+|[a-zæøå]+)\s+(minutt(?:er|et)?|minut(?:ter|er|e|es)?|min|time(?:r)?|dag(?:er)?)\s+før$"#),
                  let result = expression.firstMatch(in: alarm, range: NSRange(alarm.startIndex..., in: alarm)),
                  let valueRange = Range(result.range(at: 1), in: alarm),
                  let unitRange = Range(result.range(at: 2), in: alarm) {
            let word = String(alarm[valueRange])
            let numbers = ["en":1, "ett":1, "to":2, "tre":3, "fire":4, "fem":5, "seks":6, "sju":7, "syv":7, "åtte":8, "ni":9, "ti":10, "femten":15, "tjue":20, "tretti":30, "førtifem":45, "seksti":60]
            guard let amount = Int(word) ?? numbers[word], (0...10080).contains(amount) else { return nil }
            let unit = String(alarm[unitRange])
            if unit.hasPrefix("dag") {
                guard let date = calendar.date(byAdding: .day, value: -amount, to: appointment.date) else { return nil }
                requested = date
            } else {
                requested = appointment.date.addingTimeInterval(-Double(amount) * (unit.hasPrefix("time") ? 3600 : 60))
            }
        } else if alarm.hasPrefix("klokken ") || alarm.hasPrefix("klokka ") || alarm.hasPrefix("kl. ") {
            guard let parsed = parse("Varsel " + alarm + " i dag", now: appointment.date, calendar: calendar) else { return nil }
            requested = parsed.date
        } else { return nil }
        guard requested > now && requested <= appointment.date else { return nil }
        return SpokenReminder(appointment: appointment, alert: requested, address: address, usedDefault: false)
    }
    struct Parsed { let title: String; let date: Date }
    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Parsed? {
        var text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept common mixed-language spellings produced by dictation.
        let aliases = [
            ("morgen früh", "i morgen tidlig"), ("morgen mittag", "i morgen middag"),
            ("morgen abend", "i morgen kveld"), ("heute morgen", "i dag morges"),
            ("heute mittag", "i dag middag"), ("heute abend", "i dag kveld"),
            ("halbe stunde", "en halvtime"), ("halben stunde", "en halvtime"),
            ("halv time", "halvtime"), ("stunden", "timer"), ("stunde", "time"),
            ("minuten", "minutter")
        ]
        for (old, new) in aliases { text = text.replacingOccurrences(of: old, with: new) }
        let words = ["null":0,"en":1,"ett":1,"et":1,"to":2,"tre":3,"fire":4,"fem":5,"seks":6,"sju":7,"syv":7,"åtte":8,"atte":8,"ni":9,"ti":10,"elleve":11,"tolv":12,"tretten":13,"fjorten":14,"femten":15,"seksten":16,"sytten":17,"atten":18,"nitten":19,"tjue":20,"tjueen":21,"tjueto":22,"tjuetre":23,"tjuefem":25,"tretti":30,"førti":40,"førtifem":45,"femti":50,"seksti":60]
        func number(_ s: String) -> Int? { Int(s) ?? words[s] }
        func match(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            return (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
        }
        func title(removing fragments: [String]) -> String {
            var value = text
            for fragment in fragments where !fragment.isEmpty { value = value.replacingOccurrences(of: fragment, with: "") }
            value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return value.isEmpty ? "Påminnelse" : value.prefix(1).uppercased() + value.dropFirst()
        }
        if let g = match(#"\bom\s+(?:(?:et|ett|en)\s+)?(kvarter|halvtime|time)\b"#) {
            let minutes = g[1] == "kvarter" ? 15 : (g[1] == "halvtime" ? 30 : 60)
            return Parsed(title: title(removing: [g[0]]), date: now.addingTimeInterval(Double(minutes * 60)))
        }
        if let g = match(#"\bom\s+(\d+|[a-zæøå]+)\s+(minutt(?:er|et)?|minut(?:ter|er|e|es)?|min|time(?:r)?|dag(?:er)?)\b"#),
           let amount = number(g[1]), (1...10080).contains(amount) {
            let date: Date
            if g[2].hasPrefix("dag") {
                guard let next = calendar.date(byAdding: .day, value: amount, to: now) else { return nil }
                date = next
            } else { date = now.addingTimeInterval(Double(amount) * (g[2].hasPrefix("time") ? 3600 : 60)) }
            return Parsed(title: title(removing: [g[0]]), date: date)
        }
        // Without a unit, "om 5" / "om ti" means minutes; do not consume an unknown unit.
        if let g = match(#"\bom\s+(\d+|en|ett|et|to|tre|fire|fem|seks|sju|syv|åtte|ni|ti|femten|tjue|tretti)\s*[.!?,]?\s*$"#),
           let amount = number(g[1]), (1...10080).contains(amount) {
            return Parsed(title: title(removing: [g[0]]), date: now.addingTimeInterval(Double(amount * 60)))
        }
        var hour: Int?; var minute = 0; var timeFragment = ""
        if let g = match(#"\b(?:klokken|klocken|klokka|kl\.?)\s*(\d{1,2}|[a-zæøå]+)(?:[:.]([0-9]{2}))?\b"#), let h = number(g[1]) {
            hour = h; minute = Int(g[2]) ?? 0; timeFragment = g[0]
        } else if let g = match(#"\bhalv\s+(\d{1,2}|[a-zæøå]+)\b"#), let h = number(g[1]), (1...24).contains(h) {
            hour = (h + 23) % 24; minute = 30; timeFragment = g[0]
        } else if let g = match(#"\b(\d{1,2})[:.](\d{2})\b"#) {
            hour = Int(g[1]); minute = Int(g[2])!; timeFragment = g[0]
        } else if let g = match(#"\b(\d{2})(\d{2})\b"#) {
            hour = Int(g[1]); minute = Int(g[2])!; timeFragment = g[0]
        } else if let g = match(#"\b(\d{1,2})\s+(\d{2})\b"#) {
            hour = Int(g[1]); minute = Int(g[2])!; timeFragment = g[0]
        } else if let g = match(#"\b(en|ett|to|tre|fire|fem|seks|sju|syv|åtte|ni|ti|elleve|tolv|tretten|fjorten|femten|seksten|sytten|atten|nitten|tjue|tjueen|tjueto|tjuetre)\s+(null|en|ett|to|tre|fire|fem|seks|sju|syv|åtte|ni|ti|femten|tjue|tjuefem|tretti|førti|førtifem|femti)\b"#),
                  let h = number(g[1]), let m = number(g[2]) {
            hour = h; minute = m; timeFragment = g[0]
        }
        var dayFragment = ""; var offset = 0
        if text.contains("i morgen") { dayFragment = "i morgen"; offset = 1 }
        else if text.contains("overmorgen") { dayFragment = "overmorgen"; offset = 2 }
        else if text.contains("i dag") { dayFragment = "i dag" }
        var period = ""
        if let g = match(#"\b(tidlig om morgenen|tidlig|morges|morgenen|morgen|formiddag|middag|midten av dagen|ettermiddag|kveld|kvelden|abend|mittag)\b"#) {
            // "morgen" in "i morgen" specifies a day, not a morning period.
            if g[1] != "morgen" || dayFragment != "i morgen" { period = g[0] }
            else if let g2 = match(#"\b(tidlig|morges|morgenen|formiddag|middag|ettermiddag|kveld|kvelden)\b"#) { period = g2[0] }
        }
        if hour == nil {
            if ["tidlig om morgenen", "tidlig", "morges", "morgenen", "morgen", "formiddag"].contains(period) { hour = 8 }
            else if ["middag", "midten av dagen", "middag"].contains(period) { hour = 12 }
            else if period == "ettermiddag" { hour = 15 }
            else if ["kveld", "kvelden", "abend"].contains(period) { hour = 18 }
            else { return nil }
        }
        guard let h = hour, (0...23).contains(h), (0...59).contains(minute),
              let day = calendar.date(byAdding: .day, value: offset, to: now),
              var date = calendar.date(bySettingHour: h, minute: minute, second: 0, of: day) else { return nil }
        if dayFragment.isEmpty && date <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
                  let next = calendar.date(bySettingHour: h, minute: minute, second: 0, of: tomorrow) else { return nil }
            date = next
        }
        return Parsed(title: title(removing: [timeFragment, dayFragment, period]), date: date)
    }
}
