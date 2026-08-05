# Ringer-App – Roadmap

Stand: 5. August 2026

## Als Nächstes

- [ ] Team-Seite gestalten: erste und zweite Mannschaft, Trainer und Ringer.
- [ ] Rollen und Datenschutz für öffentliche und interne Teamdaten festlegen.
- [ ] Livestream-Seite mit der endgültigen Videoquelle verbinden.

## News und Instagram

- [x] Instagram-Beiträge, Videos und Reels automatisch anzeigen.
- [x] Bilder und Videos intern in Vollbild öffnen und dort die Drehung erlauben.
- [x] Lange Beschreibungen auf einer eigenen Detailseite anzeigen.
- [x] Vereinsbeiträge mit optionalem Bild aus der App veröffentlichen.
- [x] Veröffentlichungsrechte für Admin, Trainer und Organisation einrichten.
- [x] Instagram-Zugriffstoken ausschließlich serverseitig speichern.
- [x] Serverseitige, wöchentliche Erneuerungsstrategie für den Instagram-Token
      vorbereiten.
- [ ] News-Funktionen nach jeder Meta-API-Änderung erneut kontrollieren.
- [ ] Optional: mehrere Bilder beziehungsweise Karussell-Beiträge vollständig
      innerhalb der App darstellen.

## Training, Konten und Rollen

- [x] Öffentliche Trainingszeiten nach Männer, Jugend und Bambinis gliedern.
- [x] Monatsansicht sowie Zu- und Absagen mit verpflichtendem Absagegrund.
- [x] Trainingsgruppen unabhängig von Benutzerrollen zuordnen.
- [x] Supabase-Registrierung, E-Mail-Anmeldung und dauerhafte Sitzung.
- [x] Profilbearbeitung und Mitgliedschaftsanträge.
- [x] Rollen Fan, Mitglied, Trainer, Organisation und Admin.
- [x] Mitgliederverwaltung, Genehmigungen und rollenabhängige Berechtigungen.
- [x] Vereinsmeldungen mit einstellbarer Anzeigedauer.

## Kampf- und LigaDB-Funktionen

- [ ] Vollständige Hallenadresse anbinden, sobald LigaDB einen stabilen,
      öffentlich nutzbaren Endpunkt bereitstellt. Der aktuelle Legacy-Endpunkt
      liefert nur den Ort; die neue interne Route antwortet extern mit HTTP 403.
- [ ] Prüfen, ob LigaDB künftig den zeitlichen Punkteverlauf eines Einzelkampfs
      öffentlich ausliefert.
- [ ] Ergebnisdarstellung mit weiteren echten abgeschlossenen Kämpfen prüfen.
- [x] Beide Mannschaften, Vereinslogos und kompakte Kampfkarten.
- [x] Kampfdetailseite mit LigaDB-Einzelergebnissen und Siegerfarben.
- [x] Austragungsort mit Kartenlink und Orts-Fallback.
- [x] Kommende Kämpfe und vergangene Ergebnisse automatisch trennen.

## Vor Veröffentlichung

- [ ] Push-Benachrichtigungen für Trainingserinnerungen, Terminänderungen,
      Trainingsausfälle und wichtige Vereinsmeldungen einrichten.
- [ ] Firebase Cloud Messaging für Android und APNs für iOS anbinden,
      Geräte-Tokens sicher in Supabase speichern sowie Einstellungen ergänzen.
- [ ] App-Name, Paket-ID, App-Icon und Splash-Screen finalisieren.
- [ ] Supabase-Mailversand auf die Vereinsadresse umstellen: eigenes SMTP,
      Vereins-Absender, deutsche E-Mail-Vorlagen und App-Deep-Link.
- [ ] Für die Absenderdomain SPF, DKIM und DMARC konfigurieren und Zustellung
      sowie Spam-Einstufung testen.
- [ ] Datenschutz, Impressum und benötigte Einwilligungen klären.
- [ ] Barrierefreiheit, Textskalierung und Kontraste prüfen.
- [ ] Auf kleinen und großen Android-Geräten testen.
- [ ] iPhone und iPad auf macOS mit Xcode testen.
- [ ] Release-Builds für Android und iOS erstellen und prüfen.
- [ ] Debug-Schaltflächen und Beispieldaten vor dem Release entfernen oder
      abschließend kontrollieren.

## Bereits umgesetzt – App-Grundlage

- [x] Einheitliches Design mit Header, Farbverlauf und Navigation.
- [x] App im Normalbetrieb auf Hochformat begrenzen.
- [x] Rollenbasierte Navigation und Berechtigungsprüfungen.
- [x] Supabase-Datenbank mit Row Level Security für sensible Funktionen.
- [x] Automatisierte Widget-Tests für zentrale Home- und Trainingsabläufe.
