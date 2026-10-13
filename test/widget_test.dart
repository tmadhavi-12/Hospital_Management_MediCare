import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_management/main.dart';

void main() {
  testWidgets('App starts on the login screen', (WidgetTester tester) async {
    // Nobody is logged in yet, so the login screen (Patient / Hospital / Admin) is shown first.
    await tester.pumpWidget(const HospitalApp());
    await tester.pumpAndSettle();

    expect(find.text('MediCare Connect'), findsOneWidget);
    expect(find.text('Patient login'), findsOneWidget);
  });
}
