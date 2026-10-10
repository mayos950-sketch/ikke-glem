# Datenschutzprüfung des iPhone-Codes

Keine eigenen Netzwerkserver, Drittanbieter-SDKs, Tracking-, Werbe- oder Analytics-Bibliotheken. Kein Benutzerkonto. Erinnerungen, Adressen, Kalenderauswahl und von Apple gefundene Koordinaten sind lokal in UserDefaults gespeichert. Audio wird nur an Apples Speech Framework übergeben und nicht als Datei gespeichert.

App-Privacy-Antwort für diesen Code: **Data Not Collected**. Apples Anleitung stellt klar, dass Entwickler nicht Apples eigene Erfassung durch Apple-Frameworks melden müssen. Lokal verarbeitete Daten zählen nicht als erfasst. Es wird keine Behauptung gemacht, dass sämtliche Spracheingaben immer auf dem Gerät verarbeitet werden.

PrivacyInfo.xcprivacy enthält:

- NSPrivacyTracking = false
- keine Tracking-Domains
- keine vom Entwickler erfassten Datentypen
- UserDefaults, zugelassener Grund CA92.1: lokale Appdaten und Einstellungen

Apples Systemdienste:

- Speech: lokale Verarbeitung bevorzugt, ansonsten Verarbeitung über Apples Dienste nach Systemfreigabe.
- CLGeocoder / Apple Maps: vom Nutzer genannte Adresse wird zur Ortsbestimmung verwendet.
- EventKit: freiwillig gewählter Kalender; Synchronisierung folgt der Kalenderkonto-Konfiguration.
- iPhone-Backups: folgen den Apple-/Geräteeinstellungen.
- Support-/Datenschutzlinks öffnen externe Websites in Safari. Support-Fehlerberichte auf GitHub sind öffentlich und werden vom Nutzer freiwillig eingereicht.

ITSAppUsesNonExemptEncryption ist false: keine eigene Kryptografie, ausschließlich Apple-Systemfunktionen und standardmäßige Netzwerkverschlüsselung. Bei späteren Kryptografie-/SDK-Änderungen erneut bewerten.

Quellen:

- https://developer.apple.com/app-store/app-privacy-details/ (insbesondere „You use Apple frameworks or services“)
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype

Diese Prüfung beschreibt die konkrete Implementierung und ersetzt keine Prüfung der Angaben durch den verantwortlichen Kontoinhaber.
