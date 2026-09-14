import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ringer_app/features/training/presentation/screens/trial_training_screen.dart';
import 'package:ringer_app/features/training/presentation/screens/trial_requests_panel.dart';

void main() {
  testWidgets('guest must sign in before seeing the trial form', (
    tester,
  ) async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.com',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: TrialTrainingScreen(client: client)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anmelden / Registrieren'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(calls, 0);
  });

  Map<String, dynamic> request(int count, {String? status}) => {
    'id': 1,
    'user_id': 'account-1',
    'full_name': 'Frank Fan',
    'training_group': 'Männer',
    'created_at': '2026-09-01T12:00:00Z',
    'status': status ?? (count == 4 ? 'completed' : 'contacted'),
    'trial_training_visits': List.generate(
      count,
      (i) => {
        'id': i + 1,
        'request_id': 1,
        'attended_on': '2026-09-0${i + 1}',
        'voided_at': null,
      },
    ),
  };

  Future<void> showPanel(WidgetTester tester, Map<String, dynamic> row) async {
    final client = SupabaseClient(
      'https://example.com',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/trial_training_visits')
                ? row['trial_training_visits']
                : [row],
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: TrialRequestsPanel(client: client, staff: true)),
      ),
    );
    final loader = tester.widget<FutureBuilder<List<Map<String, dynamic>>>>(
      find.byType(FutureBuilder<List<Map<String, dynamic>>>),
    );
    await tester.runAsync(() async {
      await loader.future;
    });
    await tester.pumpAndSettle();
  }

  testWidgets('staff can track approved trials below four visits', (
    tester,
  ) async {
    await showPanel(tester, request(3));
    expect(find.text('3 / 4 Probetrainings absolviert'), findsOneWidget);
    expect(find.text('Teilnahme erfassen'), findsOneWidget);
    await tester.tap(find.text('Teilnahmeverlauf'));
    await tester.pumpAndSettle();
    expect(find.text('02.09.2026'), findsOneWidget);
    expect(find.byTooltip('Fehleintrag korrigieren'), findsNWidgets(3));
  });

  testWidgets('four visits cannot be extended from the staff UI', (
    tester,
  ) async {
    await showPanel(tester, request(4));
    expect(find.text('4 / 4 Probetrainings absolviert'), findsNothing);
    await tester.tap(find.text('Archiv (1)'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4 Probetrainings absolviert'), findsOneWidget);
    expect(find.text('Teilnahme erfassen'), findsNothing);
    expect(find.text('Freigeben'), findsNothing);
  });

  testWidgets('today requests allow recording an earlier actual visit', (
    tester,
  ) async {
    final row = request(0)..['created_at'] = DateTime.now().toIso8601String();
    await showPanel(tester, row);
    await tester.ensureVisible(find.text('Teilnahme erfassen'));
    await tester.tap(find.text('Teilnahme erfassen'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateTime(2000));
    final now = DateTime.now();
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    expect(localizations.firstDayOfWeekIndex, 1);
    expect(localizations.formatMonthYear(DateTime(2026, 10)), 'Oktober 2026');
    await tester.tap(find.byTooltip(localizations.previousMonthTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    final chosen = DateTime(now.year, now.month - 1, 15);
    final date = '15.${chosen.month.toString().padLeft(2, '0')}.${chosen.year}';
    expect(find.textContaining('am $date bestätigen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });

  testWidgets('pending request needs approval before recording visits', (
    tester,
  ) async {
    await showPanel(tester, request(0, status: 'open'));
    expect(find.text('Freigeben'), findsOneWidget);
    expect(find.text('Teilnahme erfassen'), findsNothing);
  });

  testWidgets('voided visits remain in history but do not count', (
    tester,
  ) async {
    final row = request(4, status: 'contacted');
    (row['trial_training_visits'] as List).last['voided_at'] =
        '2026-09-05T12:00:00Z';
    await showPanel(tester, row);
    expect(find.text('3 / 4 Probetrainings absolviert'), findsOneWidget);
    expect(find.text('Teilnahme erfassen'), findsOneWidget);
  });
}
