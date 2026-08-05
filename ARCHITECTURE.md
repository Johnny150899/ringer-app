# Projektstruktur

Die App ist nach Funktionen gegliedert. Dadurch bleibt alles, was zu einem
Bereich gehört, an einer Stelle.

```text
lib/
├── app/                         App-Start, Theme und Navigation
├── core/                        Feature-übergreifende Konstanten und Widgets
└── features/
    └── <feature>/
        ├── data/                Externe Datenquellen und technische Services
        │   ├── services/
        │   └── sources/
        ├── domain/              Fachliche Datenmodelle
        │   └── models/
        └── presentation/        Screens und UI-Widgets
            ├── screens/
            └── widgets/
```

## Abhängigkeitsrichtung

- `presentation` darf `domain` und `data` verwenden.
- `data` darf `domain` verwenden.
- `domain` bleibt unabhängig von Flutter-Widgets und Datenbankzugriffen.
- Gemeinsam genutzte Bestandteile gehören nur dann nach `core`, wenn sie von
  mehreren Features benötigt werden.

## Neue Dateien einordnen

- Supabase-, HTTP- oder Speicherzugriff: `data/services`
- Statische bzw. lokale Datenquelle: `data/sources`
- Reines Datenmodell: `domain/models`
- Vollständige Seite: `presentation/screens`
- Wiederverwendbarer Teil einer Seite: `presentation/widgets`

Große Screens werden schrittweise aufgeteilt. Zustands- und Lade-Logik bleibt
im Screen; eigenständige, rein visuelle Bausteine wandern nach `widgets`.
