import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/main.dart';
import 'package:ringer_app/features/matches/presentation/screens/home_screen.dart';
import 'package:ringer_app/features/matches/presentation/screens/match_detail_screen.dart';

void main() {
  testWidgets('main navigation displays all destinations', (tester) async {
    await tester.pumpWidget(const RingerApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
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
