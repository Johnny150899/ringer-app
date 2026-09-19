import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ringer_app/features/auth/presentation/screens/membership_application_screen.dart';

void main() {
  testWidgets(
    'reviewer sees contact and must claim before approval; archive stays separate',
    (tester) async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'user_id': '1',
                'first_name': 'Anna',
                'last_name': 'Test',
                'email': 'anna@example.org',
                'status': 'received',
                'assigned_to': null,
              },
              {
                'user_id': '2',
                'first_name': 'Ben',
                'last_name': 'Archiv',
                'email': 'ben@example.org',
                'status': 'rejected',
                'assigned_to': null,
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MembershipApplicationScreen(staff: true, client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anna Test'), findsOneWidget);
      expect(find.text('Ben Archiv'), findsNothing);
      expect(find.text('Jahresbeitrag: 70 €'), findsOneWidget);
      expect(find.text('Übernehmen'), findsOneWidget);
      expect(find.text('Genehmigen'), findsNothing);
      await tester.tap(find.text('Archiv'));
      await tester.pumpAndSettle();
      expect(find.text('Ben Archiv'), findsOneWidget);
      expect(find.text('Übernehmen'), findsNothing);
    },
  );
  testWidgets('failed request shows retry instead of empty success', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response('{}', 403, request: request),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipApplicationScreen(staff: true, client: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Anträge nicht verfügbar · Erneut versuchen'),
      findsOneWidget,
    );
  });
}
