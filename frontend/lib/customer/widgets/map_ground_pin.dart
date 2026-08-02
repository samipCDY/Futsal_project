import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A futsal ground marker on the map. Only grounds we know about ever get
/// a pin here — there's no generic points-of-interest layer to filter out.
class MapGroundPin extends StatelessWidget {
  final String? priceLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  const MapGroundPin({super.key, this.priceLabel, this.isSelected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (priceLabel != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(
                priceLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          Container(
            width: isSelected ? 40 : 32,
            height: isSelected ? 40 : 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.darkGreen : AppColors.primaryGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Icon(Icons.sports_soccer, color: Colors.white, size: isSelected ? 20 : 16),
          ),
        ],
      ),
    );
  }
}

/// The user's own position on the map.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF3B82F6),
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
      ),
    );
  }
}
