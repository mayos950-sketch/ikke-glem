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

let at1741 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 17, minute: 41, second: 16))!
let doctor = NorwegianDateParser.parseSpoken("legen klokken 18 idag minn meg klokken 1741", now: at1741, calendar: calendar)!
precondition(doctor.appointment.title == "Legen")
precondition(calendar.component(.hour, from: doctor.appointment.date) == 18)
precondition(abs(doctor.alert.timeIntervalSince(at1741) - 5) < 0.01)
let compactDoctor = NorwegianDateParser.parseSpoken("legen klokken18 idag minn meg klokken1741", now: at1741, calendar: calendar)!
precondition(abs(compactDoctor.alert.timeIntervalSince(at1741) - 5) < 0.01)
precondition(NorwegianDateParser.parseSpoken("legen klokken 18 idag minn meg klokken 1740", now: at1741, calendar: calendar) == nil)
let directCurrent = NorwegianDateParser.parseSpoken("minn meg 1741", now: at1741, calendar: calendar)!
precondition(abs(directCurrent.alert.timeIntervalSince(at1741) - 5) < 0.01)
let futureDoctor = NorwegianDateParser.parseSpoken("legen klokken 18 idag minn meg klokken 1742", now: at1741, calendar: calendar)!
precondition(calendar.component(.minute, from: futureDoctor.alert) == 42)
checkAlert("minn meg klokken 17 20", 7, 17, 20)
checkAlert("minn meg klokken sytten tjue", 7, 17, 20)
print("Current-minute alert and compact Norwegian clock checks passed")

checkAlert("minn meg imorgen 8", 8, 8)
checkAlert("minn meg imorgen klokken åtte", 8, 8)
checkAlert("minn meg imorgen 1430", 8, 14, 30)
checkAlert("minn meg imorgen 00:00", 8, 0)
checkAlert("minn meg imorgen 2359", 8, 23, 59)
for hour in 0...23 {
    for minute in 0...59 {
        for time in [String(format: "%02d:%02d", hour, minute), String(format: "%02d%02d", hour, minute)] {
            let parsed = NorwegianDateParser.parseSpoken("minn meg imorgen " + time, now: now, calendar: calendar)!
            let parts = calendar.dateComponents([.day, .hour, .minute], from: parsed.alert)
            precondition(parts.day == 8 && parts.hour == hour && parts.minute == minute, time)
        }
    }
}
precondition(NorwegianDateParser.parseSpoken("minn meg imorgen 2400", now: now, calendar: calendar) == nil)
precondition(NorwegianDateParser.parseSpoken("minn meg imorgen 2360", now: now, calendar: calendar) == nil)
print("All 1,440 next-day clock times passed in colon and compact formats")

checkAlert("Minn meg klokken 17:43 i dag", 7, 17, 43)
checkAlert("Minn meg i dag klokka sytten femtifem", 7, 17, 55)
checkAlert("Minn meg i morgen klokken tjue to femti sju", 8, 22, 57)
checkAlert("Minn meg i morgen tjueen førtifem", 8, 21, 45)
checkAlert("Minn meg imorgon 18:03", 8, 18, 3)
checkAlert("Minn meg i dag klokken 23.59", 7, 23, 59)
checkAlert("Minn meg i morgen klokken 00:01", 8, 0, 1)
checkAlert("Minn meg i morgen 14 15", 8, 14, 15)
checkAlert("Legen i morgen klokken 18, minn meg i dag klokken 17:30", 7, 17, 30)
checkAlert("Legen i morgen klokken 18, minn meg klokken 17:30", 8, 17, 30)
precondition(NorwegianDateParser.parseSpoken("Minn meg i dag 09:00", now: now, calendar: calendar) == nil)
print("Spoken word clock, today/tomorrow and explicit alarm day checks passed")
