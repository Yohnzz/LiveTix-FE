import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/main.dart';

void main() {
  testWidgets('LiveTixApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LiveTixApp());

    // Verify splash screen or initial elements render.
    expect(find.byType(LiveTixApp), findsOneWidget);

    // Settle splash timers
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
