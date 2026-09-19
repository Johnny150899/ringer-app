# Mitgliedschaft, Aufgaben und Berechtigungen

Migrationen 022 und danach 023 ausführen. Migration 023 übernimmt vorhandene Trainer- und Orga-Zuweisungen in zwei unabhängige boolesche Felder. Die bisherige `role` bleibt als kompatible Projektion für ältere Ansichten bestehen; sie ist kein Speicher für die gesamte Aufgabenkombination mehr.

- Mitgliedschaft: bestehender Genehmigungsstatus. Aufgabenbearbeitung verändert diesen nicht.
- Vereinsaufgaben: Trainer, Organisation, beide oder keine. Nur Admins weisen sie bestätigten Vereinskonten zu.
- Adminrechte: separat vergeben/entziehen; Aufgaben bleiben erhalten. Eigene Adminrechte können nicht versehentlich entfernt werden.
- Mitgliedschaftsanträge: Admins sowie ausdrücklich freigeschaltete Orga-Personen. Entfernen der Orga-Aufgabe löscht deren Zusatzfreigabe; spätere Wiederzuweisung stellt diese nicht automatisch wieder her.
- Trainingsgruppen/Teilnahmeberechtigung: weiterhin separat. Traineraufgabe macht niemanden automatisch zum aktiven Ringer.
- Entzug des Vereinszugangs: löscht Aufgaben, Trainingszuordnungen und Antragsfreigabe. Das ist eine administrative Kontozugriffsänderung, kein automatischer Kündigungsprozess.

Benutzerverwaltung → Person antippen → Rollen. Mehrfach zugewiesene Personen erscheinen in beiden Aufgabenfiltern. Die Liste zeigt Name und Rollen; Trainingsgruppen und Antragsfreigabe werden ebenfalls auf der Personenseite bearbeitet. Profil zeigt alle Aufgaben. Trainerfunktionen bleiben auf Trainer/Admins beschränkt, Vereinsinhalte stehen Trainer/Organisation/Admin zur Verfügung.

Für die neue Detailseite zusätzlich Migration `20260919_024_person_settings.sql` nach 022/023 ausführen. Alle Änderungen einer Person werden mit einem RPC in einer Transaktion gespeichert. Ein zwischenzeitlich geändertes Profil wird anhand von `updated_at` erkannt und nicht überschrieben. Bei Fehlern bleibt der Entwurf erhalten. Ungeprüfte Konten sind schreibgeschützt. Das Entfernen eigener Adminrechte ist gesperrt. Bei Adminänderungen und Zugangsentzug wird erneut bestätigt. Beim Verlassen ungespeicherter Änderungen erscheint eine Warnung, auch beim Tabwechsel über die Navbar.

Serverprüfung vor Freigabe von 024: Nicht berechtigte Konten abweisen; Trainer mit zusätzlichen Rollen-/Admin-/Antragsparametern abweisen; Trainer dürfen nur Gruppen speichern; ungültige Gruppen und nicht genehmigte Profile abweisen; veraltete Zeitstempel abweisen; eigene Adminrechte schützen; alle Änderungen müssen bei einem Fehler gemeinsam zurückrollen. Migration 024 wurde lokal erstellt, nicht auf dem Server ausgeführt.

Vor Produktion serverseitig mit getrennten Konten testen: Nicht-Admin darf set_profile_tasks nicht aufrufen; direkte UPDATE-Versuche auf die neuen Spalten müssen scheitern; ungeprüfte Konten dürfen keine Aufgaben erhalten; Kombination und einzelnes Entfernen prüfen; Orga-Freigabeentzug und Admin-Selbstschutz prüfen. Die Migration wurde hier nicht gegen eine laufende Supabase-Instanz ausgeführt. Nach Umstellung App neu starten bzw. betroffene Konten neu anmelden.
