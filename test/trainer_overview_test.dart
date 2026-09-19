import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/features/training/presentation/screens/training_screen.dart';

void main() {
  testWidgets('slow schedule loads without exception or fake attendance', (
    tester,
  ) async {
    final ready = Completer<void>();
    var remoteAccepted = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final schedule = request.url.path.endsWith('/weekly_training_schedule');
        if (schedule) await ready.future;
        return http.Response(
          jsonEncode(
            schedule
                ? [
                    {
                      'id': 1,
                      'group_name': 'Männer',
                      'weekday': 2,
                      'start_hour': 18,
                      'start_minute': 0,
                      'end_hour': 20,
                      'end_minute': 0,
                      'location_name': 'Halle',
                      'location_query': 'Halle',
                    },
                  ]
                : request.url.path.endsWith('/weekly_training_responses') &&
                      remoteAccepted
                ? [
                    {
                      'user_id': 'another-member',
                      'status': 'accepted',
                      'profiles': {'first_name': 'Anna', 'last_name': 'Test'},
                    },
                  ]
                : [],
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(
            canManageSessions: true,
            supabaseClient: client,
            nowOverride: DateTime(2026, 9, 15, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Trainingsplan noch nicht geladen'),
      findsWidgets,
    );
    expect(find.textContaining('3 Zusagen'), findsNothing);
    expect(find.byTooltip('Einzeltermin bearbeiten'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0 Zusagen · 0 Absagen · 0 offen'), findsOneWidget);
    expect(find.byTooltip('Einzeltermin bearbeiten'), findsOneWidget);
    // A remote response must replace cached counts after returning to the app.
    remoteAccepted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('1 Zusagen · 0 Absagen · 0 offen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'trainer sees upcoming week across month boundary and can switch to month',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingScreen(
              canManageSessions: true,
              nowOverride: DateTime(2026, 9, 30, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trainerübersicht'), findsNothing);
      expect(find.text('01.10.2026'), findsOneWidget);
      expect(find.text('06.10.2026'), findsNothing);
      expect(find.text('29.09.2026'), findsOneWidget);
      expect(find.text('Zusagen'), findsNothing);
      await tester.tap(find.text('Monat'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('01.09.2026'), findsOneWidget);
    },
  );

  testWidgets(
    'members share upcoming and monthly views without management rights',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingScreen(
              memberAccess: true,
              nowOverride: DateTime(2026, 9, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trainerübersicht'), findsNothing);
      expect(find.text('Diese Woche'), findsOneWidget);
      expect(find.text('01.10.2026'), findsOneWidget);
      expect(find.byTooltip('Einzeltermin bearbeiten'), findsNothing);
      await tester.tap(find.text('Monat'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
    },
  );

  testWidgets('calendar week includes earlier sessions in the same week', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingScreen(
            canManageSessions: true,
            nowOverride: DateTime(2026, 9, 15, 21),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('15.09.2026'), findsOneWidget);
    expect(find.text('17.09.2026'), findsOneWidget);
  });
}
