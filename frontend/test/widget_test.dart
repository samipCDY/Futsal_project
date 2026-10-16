import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:futsal_app/app.dart';
import 'package:futsal_app/core/providers/auth_provider.dart';
import 'package:futsal_app/core/providers/profile_provider.dart';
import 'package:futsal_app/core/screens/splash_screen.dart';

void main() {
  setUpAll(() async {
    // AuthProvider reads Supabase's session; start it with no saved session
    // so the app sees a signed-out user. No network calls are made.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  testWidgets('shows the splash, then the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
            create: (_) => ProfileProvider(),
            update: (_, auth, profile) => profile!..setUser(auth.userId),
          ),
        ],
        child: const FutsalApp(),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 3)); // splash time
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('FUTSAL FINDER'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
