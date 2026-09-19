import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/features/matches/presentation/screens/home_screen.dart';
import 'package:ringer_app/features/league/presentation/screens/league_screen.dart';

void main() {
  for (final completed in [true, false]) {
    testWidgets('season message requires results: $completed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              nowOverride: DateTime(2027, 1, 10),
              matchesOverride: [
                {
                  'KampftagIst': '2026-12-12',
                  'Beginn': '20:00',
                  'HeimMannschaft': 'KSC Olympia',
                  'GastMannschaft': 'Test',
                  if (completed) 'PunkteHeimWertung': 20,
                  if (completed) 'PunkteGastWertung': 12,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Im September geht’s wieder auf die Matte.'),
        completed ? findsOneWidget : findsNothing,
      );
      expect(find.text('Nächster Kampf'), findsNothing);
      expect(find.text('Saison 2026 abgeschlossen'), completed ? findsOneWidget : findsNothing);
      expect(find.text('Zur Saisontabelle'), completed ? findsOneWidget : findsNothing);
      if (completed) {
        await tester.tap(find.text('2. Mannschaft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Zur Saisontabelle'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final table = tester.widget<LeagueScreen>(find.byType(LeagueScreen));
        expect(table.initialSeason, 2026);
        expect(table.initialTeamIndex, 2);
      }
    });
  }
}
