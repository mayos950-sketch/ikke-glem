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

func checkAlert(_ input: String, _ day: Int, _ hour: Int, _ minute: Int = 0) {
    guard let parsed = NorwegianDateParser.parseSpoken(input, now: now, calendar: calendar) else { fatalError("No spoken result: \(input)") }
    let parts = calendar.dateComponents([.day, .hour, .minute], from: parsed.alert)
    precondition(parts.day == day && parts.hour == hour && parts.minute == minute, input)
}
checkAlert("Legen klokken åtte i morgen, minn meg på det 30 minutter før", 8, 7, 30)
checkAlert("Legen klokken åtte i morgen, varsle meg klokken sju", 8, 7)
checkAlert("Legen klokken åtte i morgen, minn meg to timer før", 8, 6)
checkAlert("Legen klokken åtte i morgen, minn meg ved avtalen", 8, 8)
checkAlert("Legen klokken åtte i morgen, minn meg en halvtime før", 8, 7, 30)
checkAlert("Legen klokken åtte i morgen, minn meg 15 minutter før, adresse Storgata 12 Lillestrøm", 8, 7, 45)
checkAlert("Legen klokken åtte i morgen, adresse Storgata 12 Lillestrøm, minn meg 15 minutter før", 8, 7, 45)
precondition(NorwegianDateParser.parseSpoken("Legen klokken åtte i morgen, minn meg 15 minutter før, adresse Storgata 12 Lillestrøm", now: now, calendar: calendar)?.address == "Storgata 12 Lillestrøm")
precondition(NorwegianDateParser.parseSpoken("Legen klokken åtte i morgen, minn meg kanskje før", now: now, calendar: calendar) == nil)
precondition(NorwegianDateParser.parseSpoken("Legen klokken åtte i morgen, varsle meg klokken ni", now: now, calendar: calendar) == nil)
precondition(NorwegianDateParser.parseSpoken("Legen klokken tretten i dag, minn meg to timer før", now: now, calendar: calendar) == nil)
print("Custom notification time checks passed")

checkAlert("Minn meg om ti minutter", 7, 12, 10)
checkAlert("Minn meg i morgen tidlig", 8, 8)
checkAlert("Minn meg ring Petra i morgen tidlig", 8, 8)
checkAlert("Minn meg ring Petra i morgen tidlig klokken ni", 8, 9)
precondition(NorwegianDateParser.parseSpoken("Minn meg i morgen tidlig", now: now, calendar: calendar)?.usedDefault == false)
print("Direct reminder checks passed")
