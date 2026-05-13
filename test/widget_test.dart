import 'package:flutter_test/flutter_test.dart';
import 'package:one_hunderd/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SavingsChallengeApp());

    // Auth screen should show the title
    expect(find.text('100-Day Challenge'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
