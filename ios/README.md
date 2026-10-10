# ikke glem by MP – native iPhone-App

Einmal auf den grünen Knopf tippen und auf Norwegisch eine Erinnerung sagen. Nach dem finalen Sprachergebnis oder drei Sekunden ohne neue Transkription wird sie gespeichert. Optional kann unter **Hjelp og personvern** Text eingegeben werden.

Beispiele:

- „Minn meg om ti minutter“ → Alarm in zehn Minuten.
- „Nøkkel ligger i skapet, minner meg 655“ → nächstes 06:55 mit dem Text „Nøkkel ligger i skapet“.
- „Legen klokken 18 i dag, minn meg klokken 17:41“ → Termin 18:00, Alarm 17:41.
- „Legen klokken åtte i morgen, minn meg en halvtime før“ → Termin morgen 08:00, Alarm 07:30.

Ohne eigene Alarmzeit gilt der Terminzeitpunkt. Die App plant lokale iPhone-Mitteilungen auch bei geschlossener App. Ton, Fokus und Lautlosmodus folgen den iPhone-Einstellungen. Kein kritischer Systemwecker. Kalendereinträge entstehen nur durch **Legg i kalender** bei der jeweiligen Erinnerung. Die Kalenderwahl legt nur das Ziel fest; Google-Kalender muss vorher als iPhone-Kalenderkonto eingerichtet sein. Adressen können in Maps geöffnet werden.

## Installation und Veröffentlichung

Das Projekt `ios/IkkeGlem.xcodeproj` in Xcode öffnen, unter **Signing & Capabilities → Team** das eigene Apple-Team wählen. Für die persönliche Geräteinstallation das iPhone auswählen und Run drücken. Für TestFlight/App Store ist eine kostenpflichtige Apple Developer Program-Mitgliedschaft und ein signiertes Archiv nötig.

Die genaue Upload-Anleitung und vorbereiteten Store-Texte stehen in `ios/AppStore/UPLOAD-DE.md` und `ios/AppStore/metadata-nb.md`. Marketing-Version 1.0, Build 4; die Versionsnummer erscheint nicht im App-Bildschirm.

## Prüfumfang

GitHub Actions führt die norwegischen Parserprüfungen aus, erstellt ein unsigniertes Release-Archiv und einen Simulator-Build. Das Release-Archiv wird auf App-Icon, Datenschutzmanifest, Info.plist und Fanfare geprüft. Zwei echte Simulator-Screenshots mit fiktiven Beispieldaten und ein ZIP des iPhone-Projekts werden im Artefakt **ikke-glem-appstore** bereitgestellt.

Signierung, Apple Validate App und Sprach-/Benachrichtigungstests auf einem echten iPhone erfolgen vor der Einreichung. Simulator-Screenshots beweisen keine funktionierende Sprachaufnahme oder Zustellung auf einem echten Gerät.

Die App verwendet ausschließlich Apple-Frameworks und lokale Speicherung. Datenschutzinformationen stehen in `privacy.html`, `ios/AppStore/privacy-review.md` und in der App unter **Hjelp og personvern**.


Erkannter Satz und Statusmeldung verschwinden zehn Sekunden nach Ende der Verarbeitung. Neue Eingabe oder Statusänderung startet die Wartezeit neu. Datenschutzwarnung und gespeicherte Erinnerungen bleiben sichtbar.
