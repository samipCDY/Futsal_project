import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ground_model.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';

/// A day's 1-hour slots as an even grid, three per row. Taken slots, and
/// any [canPick] says no to, are crossed out and can't be tapped.
class SlotGrid extends StatelessWidget {
  final List<SlotModel> slots;
  final SlotModel? selected;
  final ValueChanged<SlotModel> onSelect;
  final bool Function(SlotModel)? canPick;

  const SlotGrid({super.key, required this.slots, required this.selected, required this.onSelect, this.canPick});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final slot in slots)
              SizedBox(
                width: width,
                child: _SlotTile(
                  slot: slot,
                  open: slot.available && (canPick?.call(slot) ?? true),
                  selected: selected == slot,
                  onTap: () => onSelect(slot),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One bookable hour: its time and price.
class _SlotTile extends StatelessWidget {
  final SlotModel slot;
  final bool open;
  final bool selected;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.open, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colour = selected ? Colors.white : (open ? AppColors.textPrimary : AppColors.textSecondary);
    final strike = open ? null : TextDecoration.lineThrough;
    return Material(
      color: selected ? AppColors.primaryGreen : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.divider),
      ),
      child: InkWell(
        onTap: open ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(formatClock(slot.startTime),
                  style: TextStyle(color: colour, fontWeight: FontWeight.w600, decoration: strike)),
              const SizedBox(height: 2),
              Text(formatRupees(slot.price), style: TextStyle(color: colour, fontSize: 11, decoration: strike)),
            ],
          ),
        ),
      ),
    );
  }
}
