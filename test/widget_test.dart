import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanzasApp());
    await tester.pumpAndSettle();

    // Verify auth screen is shown
    expect(find.text('Finanzas App'), findsOneWidget);
  });
}
