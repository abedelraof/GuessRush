import 'package:flutter_test/flutter_test.dart';

import 'package:quizo/main.dart';

void main() {
  testWidgets('Home screen shows the play button', (WidgetTester tester) async {
    await tester.pumpWidget(const QuizoApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('GUESS IT!'), findsOneWidget);
    expect(find.text('PLAY NOW'), findsOneWidget);
  });

  testWidgets('Play Now navigates to categories', (WidgetTester tester) async {
    await tester.pumpWidget(const QuizoApp());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('PLAY NOW'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a category'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
  });
}
