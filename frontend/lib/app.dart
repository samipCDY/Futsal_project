import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/providers/profile_provider.dart';
import 'core/routes/app_router.dart';
import 'core/widgets/palette_scope.dart';

class FutsalApp extends StatelessWidget {
  const FutsalApp({super.key});

  static ThemeData _theme(AppPalette palette, Brightness brightness) => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: palette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.primaryGreen,
          primary: palette.primaryGreen,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          brightness: brightness,
        ),
        dividerColor: palette.divider,
      );

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ProfileProvider>().themeMode;

    return MaterialApp(
      title: 'Futsal Finder',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _theme(AppPalette.light, Brightness.light),
      darkTheme: _theme(AppPalette.dark, Brightness.dark),
      builder: (context, child) => PaletteScope(child: child!),
      home: const AppRouter(),
    );
  }
}
