# Ikke glem – native iPhone-App

Einmal **Snakk** tippen und z. B. „Legen klokken åtte i morgen“ sagen. Nach einer kurzen Sprechpause wird der Termin automatisch gespeichert. Du kannst die Zeit mitsprechen: „minn meg 30 minutter før“ oder „varsle meg klokken sju“. Das iPhone plant die lokale Mitteilung zum gewünschten Zeitpunkt, ohne Kalender-Import und ohne laufende App. Beim ersten Start sind Freigaben für Mikrofon, Spracherkennung und Mitteilungen erforderlich.

## Auf dem iMac installieren

1. Dieses Repository als ZIP herunterladen und entpacken.
2. `ios/IkkeGlem.xcodeproj` in Xcode öffnen.
3. Das Ziel **IkkeGlem** → **Signing & Capabilities** öffnen und unter **Team** deine Apple-ID auswählen. Bei Bedarf eine eigene eindeutige Bundle-ID eintragen.
4. iPhone per Kabel verbinden, entsperren und dem Mac vertrauen. Falls Xcode darum bittet, den Entwicklermodus auf dem iPhone aktivieren.
5. Oben das iPhone als Ziel wählen und **▶ Run** drücken.
6. Beim ersten Tippen auf **Snakk** Mikrofon, Spracherkennung und Mitteilungen erlauben.

Eine persönliche Installation braucht keine Veröffentlichung im App Store. Eine kostenlose Apple-ID erfordert regelmäßiges erneutes Signieren; die App ist hier noch nicht signiert. Vorhandene Erinnerungen aus der Webseite werden nicht automatisch übernommen.

## Verhalten

- Sprache: Norwegisch Bokmål (`nb-NO`). Je nach Gerät kann Internet nötig sein.
- Beispiele: „Legen klokken 8“, „Legen klokken åtte i morgen“, „Ring Petra halv ni i morgen“, „Kjøp melk om 30 minutter“.
- Ohne Datum wird das nächste Vorkommen der Uhrzeit verwendet; „i dag“ mit vergangener Uhrzeit wird abgelehnt.
- Die gewünschte Varseltid wird mitgesprochen: „minn meg på det 30 minutter før“, „minn meg to timer før“, „varsle meg klokken sju“ oder „minn meg ved avtalen“. Unklare oder vergangene ausdrücklich genannte Zeiten werden abgelehnt. Ohne Angabe bleibt eine Stunde vorher der Standard; ist diese Zeit vorbei, wird in fünf Sekunden erinnert.
- Ende der Aufnahme: finales Sprachergebnis oder 1,8 Sekunden ohne neue Transkription. Bei längeren Sprechpausen kann ein Satz zu früh abgeschlossen werden. Die erkannte Aussage und gespeicherte Zeit werden angezeigt.
- Zum Löschen einen Listeneintrag nach links wischen. Sein geplanter Alarm wird entfernt.
- iOS-Fokus, lautloser Modus und die Mitteilungseinstellungen bestimmen, ob eine Mitteilung hörbar ist; dies ist kein kritischer Systemwecker.

## Prüfung

Die Projektstruktur und Berechtigungsangaben wurden geprüft. In der Erstellungsumgebung steht kein Xcode zur Verfügung; ein iOS-Build und ein Test auf dem echten iPhone stehen aus. Der Workflow `.github/workflows/ios-build.yml` baut ohne Signierung für den Simulator und prüft den Datumsparser.

Test auf dem iPhone: Einmal „Legen klokken åtte i morgen“ sagen → ein Listeneintrag, Termin 08:00, Alarm 07:00. Für einen schnellen Test „Test om to minutter“ sagen und die App schließen: eine Mitteilung sollte nach etwa fünf Sekunden erscheinen. Danach den Testeintrag löschen.
