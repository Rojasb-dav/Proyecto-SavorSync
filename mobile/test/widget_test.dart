import 'package:flutter_test/flutter_test.dart';
import 'package:savorsync/main.dart';
import 'package:savorsync/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App opens login when there is no stored session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SavorSyncApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
