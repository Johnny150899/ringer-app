import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/app/app.dart';
import 'package:ringer_app/features/matches/domain/models/team_match.dart';
import 'package:ringer_app/features/matches/presentation/screens/match_detail_screen.dart';

void main() {
  testWidgets(
    'match details retain navigation and tab switch returns to tabs',
    (tester) async {
      await tester.pumpWidget(
        RingerApp(
          firstTeamMatchesFuture: Future.value([
            TeamMatch.fromJson({
              'BegegnungsID': 1,
              'KampftagIst': '2099-09-12',
              'Beginn': '20:00',
              'HeimMannschaft': 'KSC Olympia',
              'GastMannschaft': 'Testverein',
            }),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Testverein').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MatchDetailScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(MatchDetailScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Testverein').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Training'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(MatchDetailScreen), findsNothing);
      expect(find.text('Training'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
