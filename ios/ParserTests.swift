import Foundation
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
func check(_ input: String, _ day: Int, _ hour: Int, _ minute: Int = 0) {
    guard let parsed = NorwegianDateParser.parse(input, now: now, calendar: calendar) else { fatalError("No result: \(input)") }
    let parts = calendar.dateComponents([.day, .hour, .minute], from: parsed.date)
    precondition(parts.day == day && parts.hour == hour && parts.minute == minute, input)
}
check("Legen klokken 8", 8, 8)
check("Legen klokken åtte i morgen", 8, 8)
check("Legen klocken 8 i morgen", 8, 8)
check("Ring Petra halv ni i morgen", 8, 8, 30)
check("Ring Petra klokken 14.30 i dag", 7, 14, 30)
check("Kjøp melk om to minutter", 7, 12, 2)
precondition(NorwegianDateParser.parse("Legen klokken 29", now: now, calendar: calendar) == nil)
precondition(NorwegianDateParser.parse("Legen", now: now, calendar: calendar) == nil)
let appointment = NorwegianDateParser.parse("Legen klokken åtte i morgen", now: now, calendar: calendar)!.date
precondition(calendar.component(.hour, from: appointment.addingTimeInterval(-3600)) == 7)
print("Norwegian date parser checks passed")

let spokenAddress = NorwegianDateParser.splitAddress("Legen klokken åtte i morgen, adresse Storgata 12, Lillestrøm")
precondition(spokenAddress.address == "Storgata 12, Lillestrøm")
check(spokenAddress.text, 8, 8)
precondition(NorwegianDateParser.splitAddress("Legen klokken åtte i morgen").address == nil)
precondition(NorwegianDateParser.splitAddress("Ring Petra i morgen klokken ni, adressen er Kirkegata 4 Oslo").address == "Kirkegata 4 Oslo")
print("Spoken address extraction checks passed")
