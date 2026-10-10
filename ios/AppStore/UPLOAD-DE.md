# App Store Connect – letzter Upload

Das Projekt und die Texte sind vorbereitet. Es ist noch kein signierter Build hochgeladen oder zur Prüfung eingereicht.

1. Das aktualisierte Repository als ZIP laden und entpacken. In Xcode `ios/IkkeGlem.xcodeproj` öffnen.
2. Ziel **IkkeGlem → Signing & Capabilities → Team**: das Team deiner kostenpflichtigen Apple Developer Program-Mitgliedschaft auswählen. Bundle-ID `com.marioproter.IkkeGlem` beim selben Team registrieren. Falls diese ID schon einem anderen Team gehört, muss die ID in Xcode und App Store Connect übereinstimmend geändert werden.
3. In App Store Connect → **Meine Apps → + → Neue App**: iOS, Name **ikke glem by MP**, Sprache **Norwegisch Bokmål**, passende Bundle-ID, SKU **ikke-glem-mp-ios**.
4. In Xcode das Schema **IkkeGlem**, Ziel **Any iOS Device (arm64)** wählen. **Product → Archive**. Im Organizer **Validate App** ausführen, dann **Distribute App → App Store Connect → Upload**. Ein unsigniertes CI-Archiv ist nur eine Buildprüfung und kann nicht eingereicht werden.
5. Den verarbeiteten Build zuerst in TestFlight auf einem echten iPhone testen: Zwei-Minuten-Erinnerung, App schließen, Mitteilung empfangen; Norwegian speech, 655/06:55, frei gewählte Vorwarnzeit, Kalender speichern/löschen, Maps, verweigerte Berechtigungen und Textfallback prüfen.
6. Store-Texte aus `metadata-nb.md` eintragen. Die echten Simulator-Screenshots aus dem CI-Artefakt hochladen. Die Screenshots zeigen fiktive Beispieldaten.
7. Datenschutz: **Keine Daten erfasst / Data Not Collected** für den geprüften aktuellen Code. Entwickler erhält keine Erinnerungen, Aufnahmen, Analytics oder Standortdaten. Apple-Systemdienste können Daten selbst verarbeiten; diese sind in der Datenschutzerklärung beschrieben. Siehe `privacy-review.md`. Bei künftigen Drittanbieter-SDKs oder einem Backend muss diese Antwort erneut geprüft werden.
8. Altersfreigabe-Fragebogen wahrheitsgemäß ausfüllen: keine Werbung, kein Chat, keine öffentlichen Nutzerinhalte, kein Glücksspiel, keine Gewalt-/Erwachsenen-Inhalte. Die endgültige Einstufung berechnet Apple.
9. Review-Kontakt, Verkäufername/Copyright, Preis, Länder und EU-DSA-Händlerstatus selbst bestätigen. Nicht blind „kein Händler“ auswählen.
10. Nach bestandenem Gerätetest den Build wählen, Review Notes übernehmen, Veröffentlichung auf **Manuell** setzen und zur Apple-Prüfung einreichen.

## Wichtige Angaben

- Native iPhone-App, kein Website-Wrapper.
- iOS 16 oder neuer; nur iPhone. iPad-Unterstützung ist nicht aktiviert.
- Marketing-Version 1.0, Buildnummer 2. Buildnummer vor erneutem Upload erhöhen, wenn Build 2 schon verwendet wurde.
- Shared Scheme für Archive vorhanden.
- Release-App-Icon und Datenschutzmanifest sind eingebunden.
- Keine Login-Daten für App Review notwendig.
- Mikrofon, Spracherkennung und Mitteilungen sind für Spracheingabe nötig; Kalender ist optional.
- Benachrichtigungston übersteuert Fokus oder Lautlosmodus nicht.
- CI-Release-Build ersetzt keine Prüfung von Signierung, Apple Validate App oder Tests auf dem echten Gerät.

## Apple-Quellen (geprüft 10.10.2026)

- https://developer.apple.com/app-store/submitting/
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
