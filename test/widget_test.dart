import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/main.dart';

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
}
