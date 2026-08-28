import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quizo/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Boots to the login screen when logged out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuizoApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('GUESS IT!'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('Sign up link navigates to the signup screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuizoApp());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('Already have an account? Log in'), findsOneWidget);
  });
}
