import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savorsync/core/utils/token_storage.dart';
import 'package:savorsync/main.dart';
import 'package:savorsync/screens/auth/email_verification_screen.dart';
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

  testWidgets('App resumes pending restaurant verification on startup',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage().savePendingVerification(
      email: 'restaurant@example.test',
      challengeId: 'pending-challenge',
      expiresInMs: 900000,
      requestedRole: 'restaurant_admin',
    );

    await tester.pumpWidget(const SavorSyncApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    final screen = tester.widget<EmailVerificationScreen>(
      find.byType(EmailVerificationScreen),
    );
    expect(screen.email, 'restaurant@example.test');
    expect(screen.requestedRole, 'restaurant_admin');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
