import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/main.dart';
import 'package:ringer_app/features/matches/presentation/screens/home_screen.dart';
import 'package:ringer_app/features/matches/presentation/screens/match_detail_screen.dart';
import 'package:ringer_app/features/training/presentation/screens/training_screen.dart';

void main() {
  testWidgets('main navigation displays all destinations', (tester) async {
    await tester.pumpWidget(const RingerApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Liga'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('selecting a destination changes the visible screen', (
    tester,
  ) async {
    await tester.pumpWidget(const RingerApp());

    await tester.tap(find.text('Training'));
    await tester.pump();

    expect(find.text('Training'), findsNWidgets(2));
  });

  testWidgets('livestream asks guests to create a fan account', (tester) async {
    await tester.pumpWidget(const RingerApp());

    await tester.tap(find.text('Live'));
    await tester.pump();

    expect(find.text('Livestream für Fans'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('livestream-login-button')),
      findsOneWidget,
    );
  });

  testWidgets('home separates upcoming matches and past results', (
    tester,
  ) async {
    const matches = [
      {
        'BegegnungsID': 1,
        'KampftagIst': '2026-09-13T00:00:00',
        'Beginn': '20:00',
        'HeimMannschaft': 'ASV Bruchsal',
        'GastMannschaft': 'KSC Olympia Graben-Neudorf',
        'HeimOrganisationsID': 163,
        'GastOrganisationsID': 165,
      },
      {
        'BegegnungsID': 2,
        'KampftagIst': '2026-07-01T00:00:00',
        'Beginn': '19:30',
        'HeimMannschaft': 'ASV Bruchsal',
        'GastMannschaft': 'KSC Olympia Graben-Neudorf',
        'HeimOrganisationsID': 163,
        'GastOrganisationsID': 165,
        'PunkteHeimWertung': 12,
        'PunkteGastWertung': 19,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            matchesOverride: matches,
            nowOverride: DateTime(2026, 8, 4, 12),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nächster Kampf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Letzte Ergebnisse'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Letzte Ergebnisse'), findsOneWidget);
    expect(find.text('12 : 19'), findsOneWidget);
  });

  testWidgets('training groups the public schedule by audience', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(nowOverride: DateTime(2026, 8, 3, 17)),
        ),
      ),
    );

    expect(find.text('NÄCHSTES TRAINING'), findsNothing);
    expect(find.text('Route'), findsNothing);
    expect(find.text('Männer'), findsOneWidget);
    expect(find.text('Jugend'), findsOneWidget);
    expect(find.text('Bambinis'), findsOneWidget);
    expect(find.text('2 Termine pro Woche'), findsNothing);
    expect(find.text('Aktive'), findsNothing);
    expect(find.text('Anfänger'), findsNothing);
    expect(find.text('18:00–20:00 Uhr'), findsNWidgets(2));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.textContaining('03.08.'), findsNothing);
  });

  testWidgets('training debug preview lets members respond', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(nowOverride: DateTime(2026, 8, 3, 12)),
        ),
      ),
    );

    await tester.tap(find.text('Mitgliederansicht'));
    await tester.pump();

    expect(find.text('Kommende Einheiten'), findsNothing);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-group-Männer')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-group-Jugend')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-group-Bambinis')), findsOneWidget);
    expect(find.text('Zusagen'), findsWidgets);
    expect(find.text('Absagen'), findsWidgets);
    expect(find.textContaining('2026'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('member-group-Männer')));
    await tester.pump();

    expect(find.textContaining('18:00–20:00 Uhr'), findsWidgets);
    expect(find.textContaining('17:00–19:00 Uhr'), findsNothing);

    await tester.tap(find.text('Zusagen').first);
    await tester.pump();

    final selectedButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Zusagen').first,
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      selectedButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF168A5B),
    );

    await tester.tap(find.byKey(const ValueKey('training-Männer-2026-8-4')));
    await tester.pumpAndSettle();

    expect(find.text('Teilnahmen'), findsOneWidget);
    expect(find.text('Zusagen (4)'), findsOneWidget);
    expect(find.text('Absagen (1)'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
  });

  testWidgets('approved members see the member training view automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(
            memberAccess: true,
            nowOverride: DateTime(2026, 8, 3, 12),
          ),
        ),
      ),
    );

    expect(find.text('Mitgliederansicht testen'), findsNothing);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Zusagen'), findsWidgets);
    expect(find.text('Absagen'), findsWidgets);
  });

  testWidgets('training decline requires and displays a reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(nowOverride: DateTime(2026, 8, 3, 12)),
        ),
      ),
    );

    await tester.tap(find.text('Mitgliederansicht'));
    await tester.pump();
    await tester.tap(find.text('Absagen').first);
    await tester.pumpAndSettle();

    expect(find.text('Absage begründen'), findsOneWidget);
    await tester.tap(find.text('Absage speichern'));
    await tester.pump();
    expect(find.text('Bitte gib einen Grund an.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Bin krank');
    await tester.tap(find.text('Absage speichern'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('training-Männer-2026-8-4')));
    await tester.pumpAndSettle();

    expect(find.text('Absagen (2)'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('Bin krank'), findsOneWidget);
  });

  testWidgets('match details render LigaDB individual results', (tester) async {
    const match = {
      'BegegnungsID': 78926,
      'KampftagIst': '2025-09-13T00:00:00',
      'Beginn': '20:00',
      'HeimMannschaft': 'ASV Bruchsal',
      'GastMannschaft': 'KSC Olympia Graben-Neudorf',
      'HeimOrganisationsID': 163,
      'GastOrganisationsID': 165,
      'PunkteHeimWertung': 12,
      'PunkteGastWertung': 19,
    };
    const singleMatches = [
      {
        'Stilart': 'L',
        'Gewichtsklasse': '57',
        'NameHeim': 'Abuzar Salar',
        'NameGast': 'Vincent Melechin',
        'HPunkte': 4,
        'GPUNKTE': 0,
        'KampfzeitSekunden': 66,
        'Wertung': 'SS 12:0',
      },
      {
        'Stilart': 'G',
        'Gewichtsklasse': '61',
        'NameHeim': 'Andras Tamas mit einem sehr langen Namen',
        'NameGast': 'Gast Sieger',
        'HPunkte': 0,
        'GPUNKTE': 4,
        'KampfzeitSekunden': 360,
        'Wertung': 'PS 2:8',
      },
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: MatchDetailScreen(
          match: match,
          singleMatchesOverride: singleMatches,
          venueOverride: {
            'name': 'ASV-Halle',
            'address': 'Schlossraum 34, 76646 Bruchsal',
            'isExactAddress': true,
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Abuzar Salar'), findsOneWidget);
    expect(find.text('Vincent Melechin'), findsOneWidget);
    expect(find.text('SS 12:0'), findsOneWidget);
    expect(find.text('PS 2:8'), findsOneWidget);
    expect(find.text('57 kg'), findsOneWidget);
    expect(find.text('Freistil'), findsOneWidget);

    expect(find.text('1:06 min'), findsOneWidget);

    final homeWinner = tester.widget<Text>(find.text('Abuzar Salar'));
    final homeLoser = tester.widget<Text>(find.text('Vincent Melechin'));
    expect(homeWinner.style?.color, const Color(0xFFE4003A));
    expect(homeLoser.style?.color, const Color(0xFF101828));

    final guestWinner = tester.widget<Text>(find.text('Gast Sieger'));
    expect(guestWinner.style?.color, const Color(0xFF1565C0));
  });
}
