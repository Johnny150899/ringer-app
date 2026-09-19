import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ringer_app/features/auth/presentation/screens/user_detail_screen.dart';
import 'package:ringer_app/features/auth/presentation/screens/user_management_screen.dart';
import 'package:ringer_app/app/app.dart';
import 'package:ringer_app/features/matches/presentation/screens/home_screen.dart';

void main() {
  final profile = <String, dynamic>{
    'id': 'person',
    'first_name': 'Anna',
    'last_name': 'Test',
    'role': 'member',
    'is_trainer': false,
    'is_organization': false,
    'membership_status': 'approved',
    'membership_approved_at': '2026-09-17T10:00:00Z',
    'updated_at': '2026-09-19T10:00:00Z',
    'profile_training_groups': <dynamic>[],
  };
  late List<Map<String, dynamic>> writes;
  late SupabaseClient client;
  var failSave = false;
  setUp(() {
    writes = [];
    failSave = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        Object? body;
        if (r.url.path.endsWith('/rpc/save_person_settings')) {
          writes.add(jsonDecode(r.body) as Map<String, dynamic>);
          if (failSave) {
            return http.Response(
              '{"message":"settings_changed","code":"P0001"}',
              400,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
        } else if (r.url.path.endsWith('/profiles')) {
          body =
              r.headers['Accept']?.contains('object') == true ||
                  r.headers['accept']?.contains('object') == true
              ? profile
              : [profile];
        } else {
          body = [];
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  Future<void> open(WidgetTester tester, {bool admin = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UserDetailScreen(
                    userId: 'person',
                    canManageRoles: admin,
                    client: client,
                  ),
                ),
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('list opens entire person card without old controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserManagementScreen(canManageRoles: true, client: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anna Test'), findsOneWidget);
    expect(find.text('Trainingsgruppen bearbeiten'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Anna Test'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailScreen), findsOneWidget);
    expect(find.text('Rollen'), findsOneWidget);
  });
  testWidgets('admin saves a combined draft in one call', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Trainer'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Organisation'));
    expect(writes, isEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single['trainer'], true);
    expect(writes.single['organization'], true);
    expect(writes.single['expected_updated_at'], profile['updated_at']);
    expect(find.byType(UserDetailScreen), findsNothing);
  });
  testWidgets('trainer can change groups but cannot submit admin fields', (
    tester,
  ) async {
    await open(tester, admin: false);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Trainer'),
          )
          .onChanged,
      isNull,
    );
    await tester.scrollUntilVisible(find.text('Männer'), 220);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Männer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(writes.single['assigned_groups'], ['Männer']);
    expect(writes.single.containsKey('administrator'), false);
    expect(writes.single.containsKey('trainer'), false);
  });
  testWidgets('failed save keeps the draft and screen open', (tester) async {
    failSave = true;
    await open(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Trainer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailScreen), findsOneWidget);
    expect(find.textContaining('inzwischen geändert'), findsOneWidget);
    expect(writes, hasLength(1));
  });
  testWidgets('navbar respects unsaved changes before changing tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      RingerApp(firstTeamMatchesFuture: Future.value([])),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserDetailScreen(
          userId: 'person',
          canManageRoles: true,
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Trainer'));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Training'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Training'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailScreen), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(writes, isEmpty);
  });
  testWidgets('leaving dirty detail asks and cancel preserves draft', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Trainer'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Trainer'),
          )
          .value,
      true,
    );
    expect(writes, isEmpty);
  });
}
