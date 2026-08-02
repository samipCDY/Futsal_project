import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GroundSearchBar extends StatelessWidget {
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;
  final String hintText;

  const GroundSearchBar({
    super.key,
    this.onFilterTap,
    this.onChanged,
    this.hintText = 'Search futsal grounds...',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: onFilterTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}
