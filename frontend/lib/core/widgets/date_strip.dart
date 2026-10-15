import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/time_format.dart';

const _chipWidth = 84.0;
const _chipGap = 8.0;

/// A sideways-scrolling row of days to pick from ("Today", "Tomorrow",
/// "Sat 18", ...). Starts scrolled so [selected] is in view.
class DateStrip extends StatefulWidget {
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  const DateStrip({super.key, required this.days, required this.selected, required this.onSelected});

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  late final _scrollController = ScrollController(
    initialScrollOffset: widget.days.indexOf(widget.selected).clamp(0, widget.days.length) * (_chipWidth + _chipGap),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (day.difference(today).inDays) {
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      case -1:
        return 'Yesterday';
      default:
        return formatDateShort(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: _chipGap),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          final label = _label(day);
          return _DayChip(
            label: label,
            sublabel: formatDateShort(day),
            selected: day == widget.selected,
            onTap: () => widget.onSelected(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({required this.label, required this.sublabel, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final showSublabel = label != sublabel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _chipWidth,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary),
            ),
            if (showSublabel)
              Text(
                sublabel,
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
