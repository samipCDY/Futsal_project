import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Points [AppColors] at the light or dark palette to match the active theme.
///
/// Most widgets read `AppColors.x` directly instead of `Theme.of(context)`, so
/// they wouldn't rebuild on their own when the theme flips. When it does, this
/// marks the whole subtree for rebuild — every widget repaints in the new
/// colors while keeping its state (open screens, tab, scroll position).
class PaletteScope extends StatefulWidget {
  final Widget child;

  const PaletteScope({super.key, required this.child});

  @override
  State<PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<PaletteScope> {
  Brightness? _brightness;

  static void _markNeedsBuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markNeedsBuild);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness != _brightness) {
      final isFirstBuild = _brightness == null;
      _brightness = brightness;
      AppColors.usePalette(brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
      if (!isFirstBuild) (context as Element).visitChildren(_markNeedsBuild);
    }
    return widget.child;
  }
}
