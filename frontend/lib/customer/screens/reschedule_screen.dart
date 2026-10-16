import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/date_strip.dart';
import '../widgets/slot_grid.dart';

const _daysToShow = 14;

/// Moves an upcoming booking to another free hour at the same ground. A
/// booking paid online can only move to an hour with the same price, so no
/// money changes hands. Pops with true once moved.
class RescheduleScreen extends StatefulWidget {
  final BookingModel booking;

  const RescheduleScreen({super.key, required this.booking});

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late final List<DateTime> _days;
  late DateTime _day;
  List<SlotModel>? _slots;
  String? _closedReason;
  String? _error;
  SlotModel? _picked;
  bool _saving = false;
  int _loadGeneration = 0;

  BookingModel get _booking => widget.booking;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = [for (var i = 0; i < _daysToShow; i++) today.add(Duration(days: i))];
    final booked = DateTime(_booking.date.year, _booking.date.month, _booking.date.day);
    _day = _days.contains(booked) ? booked : today;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _slots = null;
      _error = null;
      _picked = null;
    });
    try {
      final day = await FutsalApi.fetchSlots(_booking.groundId, _day);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _slots = day.slots;
        _closedReason = day.closedReason;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _selectDay(DateTime day) {
    if (day == _day) return;
    _day = day;
    _load();
  }

  /// Paid online: only hours costing what was paid.
  bool _canPick(SlotModel slot) => !_booking.isPaid || slot.price == _booking.price;

  Future<void> _move() async {
    final slot = _picked!;
    setState(() => _saving = true);
    try {
      await FutsalApi.rescheduleBooking(_booking.id, day: _day, startTime: slot.startTime);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Moved to ${formatDateShort(_day)}, ${formatClock(slot.startTime)}.'),
      ));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      if (e.statusCode == 409) _load(); // someone took it; show what's free now
    }
  }

  Widget _slotsSection() {
    final slots = _slots;
    if (_error != null) {
      return Column(
        children: [
          Text(_error!, style: AppTextStyles.body),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    if (slots == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_closedReason != null) {
      return Text('Closed for maintenance this day: $_closedReason. Please pick another date.',
          style: AppTextStyles.body.copyWith(color: AppColors.statusPendingText));
    }
    if (!slots.any((slot) => slot.available && _canPick(slot))) {
      return Text('No free times you can move to on this day. Try another date.', style: AppTextStyles.body);
    }
    return SlotGrid(
      slots: slots,
      selected: _picked,
      canPick: _canPick,
      onSelect: (slot) => setState(() => _picked = slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Reschedule', style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_booking.groundName, style: AppTextStyles.subheading.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Now: ${_booking.dateLabel} · ${_booking.timeLabel}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.infoBannerBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.infoBannerText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _booking.isPaid
                        ? 'You paid ${formatRupees(_booking.price)} online, so you can move to any free time with '
                            'the same price. For another price, cancel and book again.'
                        : 'Free to move. The new time\'s price applies; you pay at the ground.',
                    style: TextStyle(color: AppColors.infoBannerText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Pick a new date', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          DateStrip(days: _days, selected: _day, onSelected: _selectDay),
          const SizedBox(height: 24),
          Text('Pick a new time', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          _slotsSection(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: picked == null || _saving ? null : _move,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    picked == null
                        ? 'Select a new time'
                        : 'Move to ${formatDateShort(_day)}, ${formatClock(picked.startTime)} · '
                            '${formatRupees(picked.price)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}
