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
    static func parseSpoken(_ input: String, now: Date = Date(), calendar: Calendar = .current, language: String = "nb") -> SpokenReminder? {
        let input = normalizeLanguage(input, language: language)
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
        let parsedAppointment = parse(main.text, now: now, calendar: calendar)
        if parsedAppointment == nil, let alarmPart,
           let parsed = parse(alarmPart.text, now: now, calendar: calendar), parsed.date > now {
            let title = main.text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !title.isEmpty else { return nil }
            let reminder = Parsed(title: title.prefix(1).uppercased() + title.dropFirst(), date: parsed.date)
            return SpokenReminder(appointment: reminder, alert: parsed.date, address: main.address ?? alarmPart.address, usedDefault: false)
        }
        guard let appointment = parsedAppointment, appointment.date > now else { return nil }
        let address = main.address ?? alarmPart?.address
        guard let alarm = alarmPart?.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) else {
            return SpokenReminder(appointment: appointment, alert: appointment.date, address: address, usedDefault: true)
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
        } else if alarm.hasPrefix("klokken") || alarm.hasPrefix("klocken") || alarm.hasPrefix("klokka") || alarm.hasPrefix("kl.") || alarm.range(of: #"\b(?:klokken|klocken|klokka|kl\.?|\d{3,4}|\d{1,2}[:.]\d{2})\b"#, options: .regularExpression) != nil || alarm.range(of: #"^\d{1,2}\s+\d{2}$"#, options: .regularExpression) != nil {
            let hasDay = alarm.range(of: #"\b(?:i\s+dag|idag|i\s+morgen|imorgen|overmorgen)\b"#, options: .regularExpression) != nil
            let expression = "Varsel " + alarm + (hasDay ? "" : " i dag")
            guard let parsed = parse(expression, now: hasDay ? now : appointment.date, calendar: calendar) else { return nil }
            requested = parsed.date
        } else { return nil }
        guard requested <= appointment.date else { return nil }
        let alert: Date
        if requested <= now {
            guard calendar.isDate(requested, equalTo: now, toGranularity: .minute) else { return nil }
            alert = min(now.addingTimeInterval(5), appointment.date)
        } else { alert = requested }
        return SpokenReminder(appointment: appointment, alert: alert, address: address, usedDefault: false)
    }

    static func normalizeLanguage(_ input: String, language: String) -> String {
        guard language == "de" || language == "en" else { return input }
        // Separate the address so street names are never normalized as clock words.
        let addressPattern = language == "de" ? #"\b(?:an der adresse|adresse ist|adresse)\s*[:,]?\s+"# : #"\b(?:at the address|address is|address)\s*[:,]?\s+"#
        var text = input
        var address = ""
        if let regex = try? NSRegularExpression(pattern: addressPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            address = String(text[range.upperBound...])
            text = String(text[..<range.lowerBound])
        }
        func replace(_ pattern: String, _ replacement: String) {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        let numberWords: [String:Int] = language == "de"
            ? ["null":0,"ein":1,"eins":1,"eine":1,"einer":1,"einen":1,"zwei":2,"drei":3,"vier":4,"fünf":5,"sechs":6,"sieben":7,"acht":8,"neun":9,"zehn":10,"elf":11,"zwölf":12,"dreizehn":13,"vierzehn":14,"fünfzehn":15,"sechzehn":16,"siebzehn":17,"achtzehn":18,"neunzehn":19,"zwanzig":20,"dreißig":30,"dreissig":30,"vierzig":40,"fünfzig":50,"sechzig":60]
            : ["zero":0,"a":1,"an":1,"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,"fifteen":15,"sixteen":16,"seventeen":17,"eighteen":18,"nineteen":19,"twenty":20,"thirty":30,"forty":40,"fifty":50,"sixty":60]
        func number(_ word: String) -> Int? {
            let w = word.lowercased()
            if let n = Int(w) ?? numberWords[w] { return n }
            if language == "de" {
                for (unit,u) in numberWords where (1...9).contains(u) {
                    for (ten,t) in numberWords where [20,30,40,50].contains(t) {
                        if w == unit + "und" + ten { return t + u }
                    }
                }
            } else {
                let parts = w.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
                if parts.count == 2, let t = numberWords[parts[0]], let u = numberWords[parts[1]], [20,30,40,50].contains(t), (1...9).contains(u) { return t + u }
            }
            return nil
        }
        func convertNumbers(_ pattern: String) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let range = Range(match.range(at: 1), in: text), let n = number(String(text[range])) else { continue }
                text.replaceSubrange(range, with: String(n))
            }
        }
        if language == "de" {
            replace(#"\b(?:erinnere|erinner|erinnern)\s+mich(?:\s+daran)?(?:\s+an)?\b"#, "minn meg")
            replace(#"\bübermorgen\b"#, "overmorgen")
            replace(#"\bmorgen\s+früh\b"#, "i morgen tidlig")
            replace(#"\bheute\s+morgen\b"#, "i dag morges")
            replace(#"\bmorgen\b"#, "i morgen")
            // Avoid doubling the day introduced by the previous replacement.
            replace(#"\bi\s+i morgen\b"#, "i morgen")
            replace(#"\bheute\b"#, "i dag")
            replace(#"\b(?:eine|einer|einen)?\s*viertelstunde\b"#, "15 minutter")
            replace(#"\b(?:eine|einer|einen)?\s*halbe[nr]?\s+stunde\b"#, "30 minutter")
            replace(#"\bminuten?\b"#, "minutter")
            replace(#"\bstunden?\b"#, "timer")
            replace(#"\btage[n]?\b"#, "dager")
            replace(#"\b(?:vorher|zuvor)\b"#, "før")
            replace(#"\b(?:abends|abend)\b"#, "kveld")
            replace(#"\b(?:mittags|mittag)\b"#, "middag")
            replace(#"\b(?:nachmittags|nachmittag)\b"#, "ettermiddag")
            replace(#"\bmorgens\b"#, "morges")
            replace(#"\bum\b"#, "klokken")
            replace(#"\bin\b(?=\s+(?:\d+|[a-zäöüß-]+)\s+(?:minutter|timer|dager))"#, "om")
            convertNumbers(#"\b([a-zäöüß-]+|\d+)(?=\s+(?:minutter|timer|dager|uhr)\b)"#)
            convertNumbers(#"\bklokken\s+([a-zäöüß-]+|\d+)\b"#)
            convertNumbers(#"\bhal[bv]\s+([a-zäöüß-]+|\d+)\b"#)
            replace(#"\bhalb\b"#, "halv")
            replace(#"\b(\d{1,2}(?:[:.]\d{2})?)\s*uhr\b"#, "klokken $1")
            replace(#"\buhr\b"#, "")
        } else {
            replace(#"\bremind\s+me(?:\s+to)?\b"#, "minn meg")
            replace(#"\bday after tomorrow\b"#, "overmorgen")
            replace(#"\btomorrow\b"#, "i morgen")
            replace(#"\btoday\b"#, "i dag")
            replace(#"\bthis morning\b"#, "i dag morges")
            replace(#"\btonight\b"#, "i dag kveld")
            replace(#"\b(?:a |an )?quarter(?: of an)? hour\b"#, "15 minutter")
            replace(#"\bhalf (?:an |a )?hour\b"#, "30 minutter")
            replace(#"\bminutes?\b"#, "minutter")
            replace(#"\bhours?\b"#, "timer")
            replace(#"\bdays?\b"#, "dager")
            replace(#"\bbefore\b"#, "før")
            replace(#"\b(?:morning|early)\b"#, "morges")
            replace(#"\b(?:noon|midday)\b"#, "middag")
            replace(#"\bafternoon\b"#, "ettermiddag")
            replace(#"\bevening\b"#, "kveld")
            replace(#"\bat\b"#, "klokken")
            replace(#"\b(?:in|after)\b(?=\s+(?:\d+|[a-z -]+)\s+(?:minutter|timer|dager))"#, "om")
            convertNumbers(#"\b([a-z]+(?:[- ](?:one|two|three|four|five|six|seven|eight|nine))?|\d+)(?=\s+(?:minutter|timer|dager)\b)"#)
            convertNumbers(#"\bklokken\s+([a-z]+(?:[- ](?:one|two|three|four|five|six|seven|eight|nine))?|\d+)\b"#)
            // Also accept “eight thirty” after a clock prefix.
            convertNumbers(#"\bklokken\s+\d+\s+([a-z]+(?:[- ](?:one|two|three|four|five|six|seven|eight|nine))?)\b"#)
            convertNumbers(#"\b([a-z]+|\d+)(?=\s+[ap]\.?m\.?\b)"#)
            let ampm = try! NSRegularExpression(pattern: #"\b(\d{1,2})(?:[:.](\d{2}))?\s*([ap])\.?m\.?\b"#, options: .caseInsensitive)
            for match in ampm.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let range = Range(match.range, in: text), let hr = Range(match.range(at: 1), in: text),
                      let h = Int(text[hr]), (1...12).contains(h), let mer = Range(match.range(at: 3), in: text) else { continue }
                let minute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
                let hour = h % 12 + (text[mer].lowercased() == "p" ? 12 : 0)
                text.replaceSubrange(range, with: String(format: "klokken %d:%02d", hour, minute))
            }
            replace(#"\bklokken\s+klokken\b"#, "klokken")
        }
        convertNumbers(#"\b([a-zäöüß-]+)(?=\s*[.!?]?\s*$)"#)
        replace(#"\bklokken\s+klokken\b"#, "klokken")
        let pair = try! NSRegularExpression(pattern: #"\bklokken\s+(\d{1,2})\s+(\d{1,2})\b"#)
        for match in pair.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text), let hr = Range(match.range(at: 1), in: text), let mr = Range(match.range(at: 2), in: text),
                  let h = Int(text[hr]), let m = Int(text[mr]) else { continue }
            text.replaceSubrange(range, with: String(format: "klokken %d:%02d", h, m))
        }
        return text + (address.isEmpty ? "" : " adresse " + address)
    }

    struct Parsed { let title: String; let date: Date }
    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Parsed? {
        var text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: #"\bidag\b"#, with: "i dag", options: .regularExpression)
            .replacingOccurrences(of: #"\bimorgen\b"#, with: "i morgen", options: .regularExpression)
        // Accept common mixed-language spellings produced by dictation.
        let aliases = [
            ("morgen früh", "i morgen tidlig"), ("i morgon", "i morgen"), ("imorgon", "i morgen"), ("morgen mittag", "i morgen middag"),
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
        // Dictation can return clock numbers as words, including "femti sju" and "tjue to".
        // Convert only after relative expressions ("om fem minutter") have been handled.
        let units: [String: Int] = ["null":0,"en":1,"ett":1,"et":1,"éin":1,"ein":1,"to":2,"tre":3,"fire":4,"fem":5,"seks":6,"sju":7,"syv":7,"åtte":8,"atte":8,"ni":9]
        let tens: [String: Int] = ["tjue":20,"tretti":30,"førti":40,"femti":50]
        var clockWords = words
        for (ten, base) in tens {
            for (unit, value) in units where value > 0 {
                clockWords[ten + unit] = base + value
                clockWords[ten + "-" + unit] = base + value
            }
        }
        let combined = try! NSRegularExpression(pattern: #"\b(tjue|tretti|førti|femti)[ -]+(en|ett|et|éin|ein|to|tre|fire|fem|seks|sju|syv|åtte|atte|ni)\b"#)
        for match in combined.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text),
                  let tenRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let base = tens[String(text[tenRange])], let unit = units[String(text[unitRange])] else { continue }
            text.replaceSubrange(range, with: String(base + unit))
        }
        let wordRegex = try! NSRegularExpression(pattern: #"\b[a-zæøåé-]+\b"#)
        for match in wordRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text), let value = clockWords[String(text[range])] else { continue }
            text.replaceSubrange(range, with: String(value))
        }
        var hour: Int?; var minute = 0; var timeFragment = ""
        if let g = match(#"\b(?:(?:klokken|klocken|klokka|kl\.?)\s*)?(\d{1,2})[:.\s](\d{2})\b"#) {
            hour = Int(g[1]); minute = Int(g[2])!; timeFragment = g[0]
        } else if let g = match(#"\b(?:(?:klokken|klocken|klokka|kl\.?)\s*)?(\d{1,2})(\d{2})\b"#) {
            hour = Int(g[1]); minute = Int(g[2])!; timeFragment = g[0]
        } else if let g = match(#"\b(?:(?:klokken|klocken|klokka|kl\.?)\s*)?(en|ett|to|tre|fire|fem|seks|sju|syv|åtte|ni|ti|elleve|tolv|tretten|fjorten|femten|seksten|sytten|atten|nitten|tjue|tjueen|tjueto|tjuetre)\s+(null|en|ett|to|tre|fire|fem|seks|sju|syv|åtte|ni|ti|femten|tjue|tjuefem|tretti|førti|førtifem|femti)\b"#), let h = number(g[1]), let m = number(g[2]) {
            hour = h; minute = m; timeFragment = g[0]
        } else if let g = match(#"\b(?:klokken|klocken|klokka|kl\.?)\s*(\d{1,2}|[a-zæøå]+)(?:[:.]([0-9]{2}))?\b"#), let h = number(g[1]) {
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
        if hour == nil, let g = match(#"\b(\d{1,2}|[a-zæøå]+)\s+(?:i dag|i morgen|overmorgen)\s*$"#), let h = number(g[1]) {
            hour = h; timeFragment = g[1]
        }
        if hour == nil, let g = match(#"\b(\d{1,2}|[a-zæøå]+)\s*[.!?]?\s*$"#), let h = number(g[1]) {
            hour = h; timeFragment = g[0]
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
        if date <= now && calendar.isDate(date, equalTo: now, toGranularity: .minute) {
            date = now.addingTimeInterval(5)
        } else if dayFragment.isEmpty && date <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
                  let next = calendar.date(bySettingHour: h, minute: minute, second: 0, of: tomorrow) else { return nil }
            date = next
        }
        return Parsed(title: title(removing: [timeFragment, dayFragment, period]), date: date)
    }
}

