# Mitgliedschaftsanträge

## Aktivierung

Migration `supabase/migrations/20260917_022_membership_applications.sql` im Supabase SQL Editor ausführen. Sie übernimmt vorhandene offene Anträge, aktiviert RLS und schränkt die Genehmigungsfunktion auf Admins und benannte Orga-Personen ein. Ohne Migration ist die neue Antragsbearbeitung nicht verfügbar.

Admin: Benutzerverwaltung → Person antippen → Berechtigungen → „Mitgliedschaftsanträge bearbeiten“. Die neue gemeinsame Personenseite benötigt zusätzlich Migrationen 023 und 024. Nach Rechteänderungen das betroffene Konto neu anmelden. Admins sind immer berechtigt. Trainerrechte für Training und Probetraining bleiben unverändert.

## Ablauf

1. Antragsteller prüft Name und Konto-E-Mail sowie den Hinweis auf 70 € Jahresbeitrag; Absenden löst keine Zahlung aus.
2. Der Server speichert die Profildaten als Antragssnapshot und setzt den Status auf Eingegangen.
3. Ein Verantwortlicher übernimmt den Antrag (atomar, keine doppelte Übernahme außer Admin-Neuzuweisung).
4. Kontakt per E-Mail außerhalb der App; Adresse kann kopiert werden. Keine automatische E-Mail.
5. Nach persönlicher Klärung genehmigen oder ablehnen. Genehmigung setzt `membership_approved_at` auf den tatsächlichen Genehmigungszeitpunkt. Abgeschlossene Anträge erscheinen im Archiv.

Keine automatische Zahlung, Beitragsabrechnung, Verlängerung oder Kündigung implementiert. Weitere Vertragsbedingungen werden im persönlichen Beitrittsprozess geklärt. Antragsteller sehen nur ihren eigenen Antrag; Admins und freigeschaltete, genehmigte Orga-Konten sehen alle Anträge. Bankdaten, Gesundheitsdaten oder andere zusätzliche Profildaten werden nicht erhoben.

## Vor produktiver Freigabe prüfen

- SQL-Migration auf einer Testinstanz ausführen (hier nicht auf einem Server ausgeführt).
- Mit Fan, Trainer, freigeschalteter und nicht freigeschalteter Orga sowie Admin testen, einschließlich direkter RPC-Aufrufe.
- Zwei Verantwortliche versuchen gleichzeitig denselben Antrag zu übernehmen.
- Antrag → Übernahme → Genehmigung/Ablehnung → Archiv und Nutzerstatus prüfen.
- Zuständigkeit entziehen und Zugriff erneut prüfen. Admin kann liegengebliebene Anträge übernehmen.
- Bestehende Anträge auf Vollständigkeit der Kontaktdaten kontrollieren.
