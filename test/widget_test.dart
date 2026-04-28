import 'package:flutter_test/flutter_test.dart';

import 'package:fairai_guardian/main.dart';

void main() {
  testWidgets('Guardian Pro UI builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuardianProApp());
    expect(find.byType(GuardianProApp), findsOneWidget);
  });
}
