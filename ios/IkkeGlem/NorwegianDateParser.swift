import Foundation

enum NorwegianDateParser {
    struct Parsed { let title: String; let date: Date }
    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Parsed? {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = ["en":1,"ett":1,"to":2,"tre":3,"fire":4,"fem":5,"seks":6,"sju":7,"syv":7,"åtte":8,"atte":8,"ni":9,"ti":10,"elleve":11,"tolv":12,"tretten":13,"fjorten":14,"femten":15,"seksten":16,"sytten":17,"atten":18,"nitten":19,"tjue":20,"tjueen":21,"tjueto":22,"tjuetre":23]
        func number(_ s: String) -> Int? { Int(s) ?? words[s] }
        func match(_ pattern: String) -> (NSTextCheckingResult, [String])? {
            guard let regex = try? NSRegularExpression(pattern: pattern), let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            return (m, (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: text).map { String(text[$0]) } ?? "" })
        }
        func title(removing fragments: [String]) -> String {
            var result = text
            for fragment in fragments where !fragment.isEmpty { result = result.replacingOccurrences(of: fragment, with: "") }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return result.isEmpty ? "Påminnelse" : result.prefix(1).uppercased() + result.dropFirst()
        }
        if let (_, groups) = match(#"\bom\s+(\d+|[a-zæøå]+)\s+(minutt(?:er)?|time(?:r)?)\b"#), let n = number(groups[1]), n > 0 {
            return Parsed(title: title(removing: [groups[0]]), date: now.addingTimeInterval(Double(n) * (groups[2].hasPrefix("time") ? 3600 : 60)))
        }
        var hour: Int; var minute = 0; let timeFragment: String
        if let (_, g) = match(#"\b(?:klokken|klocken|klokka|kl\.?)\s*(\d{1,2}|[a-zæøå]+)(?:[:.]([0-5]\d))?\b"#), let h = number(g[1]) {
            hour = h; minute = Int(g[2]) ?? 0; timeFragment = g[0]
        } else if let (_, g) = match(#"\bhalv\s+(\d{1,2}|[a-zæøå]+)\b"#), let h = number(g[1]), (1...24).contains(h) {
            hour = (h + 23) % 24; minute = 30; timeFragment = g[0]
        } else { return nil }
        guard (0...23).contains(hour) else { return nil }
        let dayFragment: String
        let offset: Int
        if text.contains("i morgen") { dayFragment = "i morgen"; offset = 1 }
        else if text.contains("overmorgen") { dayFragment = "overmorgen"; offset = 2 }
        else if text.contains("i dag") { dayFragment = "i dag"; offset = 0 }
        else { dayFragment = ""; offset = 0 }
        guard let day = calendar.date(byAdding: .day, value: offset, to: now),
              var date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
        if dayFragment.isEmpty && date <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
                  let next = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) else { return nil }
            date = next
        }
        return Parsed(title: title(removing: [timeFragment, dayFragment]), date: date)
    }
}
