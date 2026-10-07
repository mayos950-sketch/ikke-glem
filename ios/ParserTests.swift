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

checkAlert("Minne meg 17:30", 7, 17, 30)
checkAlert("Minne meg 14:15", 7, 14, 15)
checkAlert("Minne meg 1803", 7, 18, 3)
checkAlert("Minne meg i morgen 1430", 8, 14, 30)
checkAlert("Minn meg 09:15", 8, 9, 15)
checkAlert("Minne meg ring Petra 14:15 i morgen", 8, 14, 15)
precondition(NorwegianDateParser.parseSpoken("Minne meg 2460", now: now, calendar: calendar) == nil)
precondition(NorwegianDateParser.parseSpoken("Minne meg 17:99", now: now, calendar: calendar) == nil)
print("Short spoken clock time checks passed")

let directMinute = NorwegianDateParser.parseSpoken("minn meg om ett minute", now: now, calendar: calendar)!
precondition(abs(directMinute.alert.timeIntervalSince(now) - 60) < 0.01)
checkAlert("minn meg om et minutt", 7, 12, 1)
checkAlert("minn meg 17 20", 7, 17, 20)
checkAlert("minn meg sytten tjue", 7, 17, 20)
checkAlert("1720", 7, 17, 20)
checkAlert("17:20", 7, 17, 20)
checkAlert("i morgen 1720", 8, 17, 20)
checkAlert("minn meg 17.20", 7, 17, 20)
print("One-minute and speech transcription clock checks passed")

checkAlert("minn meg om 5", 7, 12, 5)
checkAlert("minn meg om 10", 7, 12, 10)
checkAlert("minn meg om et kvarter", 7, 12, 15)
checkAlert("minn meg om en halvtime", 7, 12, 30)
checkAlert("minn meg om halv time", 7, 12, 30)
checkAlert("minn meg om halbe stunde", 7, 12, 30)
checkAlert("minn meg om en time", 7, 13)
checkAlert("minn meg i morgen tidlig", 8, 8)
checkAlert("minn meg i morgen tidlig 1430", 8, 14, 30)
checkAlert("minn meg i morgen middag", 8, 12)
checkAlert("minn meg i morgen kveld", 8, 18)
checkAlert("minn meg i morgen kveld 1930", 8, 19, 30)
checkAlert("minn meg i dag kveld", 7, 18)
checkAlert("minn meg i dag kveld klokken tjue", 7, 20)
checkAlert("minn meg morgen früh", 8, 8)
checkAlert("minn meg heute abend", 7, 18)
precondition(NorwegianDateParser.parseSpoken("minn meg i dag morges", now: now, calendar: calendar) == nil)
let morningNow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 7))!
for (phrase, expectedHour) in [("minn meg i dag morges", 8), ("minn meg i dag middag", 12), ("minn meg i dag kveld", 18)] {
    let parsed = NorwegianDateParser.parseSpoken(phrase, now: morningNow, calendar: calendar)!
    precondition(calendar.component(.day, from: parsed.alert) == 7 && calendar.component(.hour, from: parsed.alert) == expectedHour)
}
precondition(NorwegianDateParser.parseSpoken("minn meg om fem bananer", now: now, calendar: calendar) == nil)
print("Relative intervals and day-period checks passed")
