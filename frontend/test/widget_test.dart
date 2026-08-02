import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:futsal_app/app.dart';
import 'package:futsal_app/core/providers/auth_provider.dart';
import 'package:futsal_app/core/providers/theme_provider.dart';

void main() {
  testWidgets('shows the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const FutsalApp(),
      ),
    );

    expect(find.text('FUTSAL FINDER'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
