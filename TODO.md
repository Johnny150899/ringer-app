# Ringer-App – nächste Schritte

Stand: 5. August 2026

## Als Nächstes

- [ ] Training-Screen planen und umsetzen.
- [ ] News-Screen planen und umsetzen.
- [ ] Team-Screen mit Mannschaften und Ringern gestalten.
- [ ] Livestream-Screen und gewünschte Videoquelle festlegen.
- [ ] Profil-Icon mit einer sinnvollen vorläufigen Aktion versehen.

## Später entscheiden

- [ ] Festlegen, welche Funktionen einen Login benötigen.
- [ ] Danach Auth-Anbieter auswählen; aktueller Favorit: Supabase Auth.
- [ ] Rollen erst definieren, wenn die Anforderungen klar sind, z. B. Fan,
      Ringer, Trainer und Administrator.
- [ ] Entscheiden, welche Inhalte öffentlich und welche vereinsintern sind.

## Kampf- und LigaDB-Funktionen

- [ ] Vollständige Hallenadresse anbinden, sobald LigaDB einen stabilen,
      öffentlich nutzbaren Endpunkt bereitstellt. Der aktuelle Legacy-Endpunkt
      liefert nur den Ort; die neue interne Route antwortet extern mit HTTP 403.
- [ ] Prüfen, ob LigaDB künftig den zeitlichen Punkteverlauf eines Einzelkampfs
      öffentlich ausliefert.
- [ ] Debug-Schaltflächen vor einem Release prüfen; sie sind derzeit nur in
      Debug-Builds sichtbar.
- [ ] Ergebnisdarstellung mit weiteren echten abgeschlossenen Kämpfen prüfen.

## Vor Veröffentlichung

- [ ] Push-Benachrichtigungen für Trainingserinnerungen, Terminänderungen,
      Trainingsausfälle und wichtige Vereinsmeldungen einrichten.
- [ ] Dafür Firebase Cloud Messaging für Android sowie APNs für iOS anbinden,
      Geräte-Tokens sicher in Supabase speichern und Benachrichtigungsrechte
      sowie Abmelde-/Einstellungsmöglichkeiten in der App ergänzen.
- [ ] App-Name, Paket-ID, App-Icon und Splash-Screen finalisieren.
- [ ] Vor der öffentlichen Registrierung den Supabase-Mailversand auf die
      Vereinsadresse umstellen: eigenes SMTP, Absendername des Vereins,
      deutsche gebrandete Auth-E-Mail-Vorlagen und App-Deep-Link einrichten.
- [ ] Für die Absenderdomain SPF, DKIM und DMARC konfigurieren und Zustellung
      sowie Spam-Einstufung der Bestätigungs- und Passwort-E-Mails testen.
- [ ] Android-Internetberechtigung auch für Release-Builds kontrollieren.
- [ ] Datenschutz, Impressum und benötigte Einwilligungen klären.
- [ ] Auf kleinen und großen Android-Geräten testen.
- [ ] iPhone/iPad auf macOS mit Xcode testen.
- [ ] Debug-Testelemente und Beispielkämpfe abschließend kontrollieren.

## Bereits umgesetzt

- [x] Gemeinsames App-Design mit Header, Farbverlauf und Navigation.
- [x] Umschaltung zwischen erster und zweiter Mannschaft.
- [x] Vereinslogos und kompakte Kampfkarten.
- [x] Kampfdetailseite mit echten LigaDB-Einzelergebnissen.
- [x] Siegerfarben: Heimsieger rot, Gastsieger blau.
- [x] Kartenlink zum Austragungsort mit Orts-Fallback.
- [x] Automatische Trennung in nächsten Kampf, kommende Kämpfe und letzte
      Ergebnisse.
- [x] Vergangene Kämpfe zeigen anstelle von „VS“ den Endstand.
- [x] Debug-Vorschauen und automatisierte Flutter-Tests.
