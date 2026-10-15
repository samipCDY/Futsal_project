import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ground_model.dart';

/// "Approved" / "Pending approval" / "Rejected" label on an owner's ground.
class GroundStatusChip extends StatelessWidget {
  final GroundStatus status;

  const GroundStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon, label) = switch (status) {
      GroundStatus.approved => (AppColors.statusConfirmedBg, AppColors.statusConfirmedText, Icons.verified, 'Approved'),
      GroundStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, Icons.hourglass_top, 'Pending approval'),
      GroundStatus.rejected => (AppColors.dangerBg, AppColors.dangerText, Icons.error_outline, 'Rejected'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
