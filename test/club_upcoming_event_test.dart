import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringer_app/app/app_theme.dart';
import 'package:ringer_app/features/club/presentation/screens/club_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('next event crosses years and stays independent of calendar', (
    tester,
  ) async {
    final requests = <Uri>[];
    final nextYear = DateTime(DateTime.now().year + 1, 1, 2, 18);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final filters = request.url.queryParametersAll['starts_at'] ?? [];
        final isNextEvent =
            request.url.path.endsWith('/club_events') &&
            !filters.any((filter) => filter.startsWith('lt.'));
        return http.Response(
          jsonEncode(
            isNextEvent
                ? [
                    {
                      'id': 42,
                      'title': 'Vereinstermin im nächsten Jahr',
                      'starts_at': nextYear.toUtc().toIso8601String(),
                      'event_type': 'club',
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
        theme: AppTheme.light,
        home: Scaffold(
          body: ClubScreen(
            supabaseClient: client,
            role: 'member',
            onOpenMemberArea: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Vereinstermin im nächsten Jahr'),
      findsOneWidget,
      reason:
          '${requests.join('\n')}\n${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join('\n')}',
    );

    final nextRequest = requests.firstWhere(
      (uri) =>
          uri.path.endsWith('/club_events') &&
          uri.queryParameters['limit'] == '1',
    );
    expect(nextRequest.queryParametersAll['starts_at'], hasLength(1));
    expect(nextRequest.queryParameters['is_published'], 'eq.true');
    expect(nextRequest.queryParameters['order'], startsWith('starts_at.asc'));

    await tester.tap(find.text('Kalender'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pumpAndSettle();
    expect(find.text('Vereinstermin im nächsten Jahr'), findsOneWidget);
    expect(
      requests.where(
        (uri) =>
            uri.path.endsWith('/club_events') &&
            uri.queryParameters['limit'] == '1',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
