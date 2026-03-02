import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaky/main.dart';

void main() {
  testWidgets('App shows onboarding headline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LeakyApp()),
    );
    expect(find.textContaining('Your money doesn\'t disappear'), findsOneWidget);
  });
}
