import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:futsal_app/core/constants/app_colors.dart';
import 'package:futsal_app/core/widgets/palette_scope.dart';

/// Reads AppColors directly (not Theme.of), like most of the app's widgets.
class _Swatch extends StatelessWidget {
  const _Swatch();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const Key('swatch'), color: AppColors.surface, child: const SizedBox.square(dimension: 10));
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => taps++), child: Text('taps $taps'));
}

Widget _app(ThemeMode mode) => MaterialApp(
      themeMode: mode,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      builder: (context, child) => PaletteScope(child: child!),
      home: const Column(children: [_Swatch(), _Counter()]),
    );

Color _swatchColor(WidgetTester tester) => tester.widget<ColoredBox>(find.byKey(const Key('swatch'))).color;

void main() {
  testWidgets('switching theme recolors widgets that read AppColors and keeps their state', (tester) async {
    await tester.pumpWidget(_app(ThemeMode.light));
    expect(_swatchColor(tester), AppPalette.light.surface);

    await tester.tap(find.text('taps 0'));
    await tester.pump();

    await tester.pumpWidget(_app(ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(_swatchColor(tester), AppPalette.dark.surface);
    expect(find.text('taps 1'), findsOneWidget); // state survived the switch

    await tester.pumpWidget(_app(ThemeMode.light));
    await tester.pumpAndSettle();
    expect(_swatchColor(tester), AppPalette.light.surface);
  });
}
