import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/date_strip.dart';

const _daysToShow = 14;

/// Pick a day and a free 1-hour slot at [ground], then book it (paid in cash
/// at the ground).
class GroundBookingScreen extends StatefulWidget {
  final GroundModel ground;

  const GroundBookingScreen({super.key, required this.ground});

  @override
  State<GroundBookingScreen> createState() => _GroundBookingScreenState();
}

class _GroundBookingScreenState extends State<GroundBookingScreen> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;

  List<SlotModel>? _slots;
  String? _slotsError;
  SlotModel? _selectedSlot;
  bool _isBooking = false;

  /// Bumped on every slot load so a slow response for a previously selected
  /// day can't overwrite the slots of the day now selected.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = [for (var i = 0; i < _daysToShow; i++) today.add(Duration(days: i))];
    _selectedDay = today;
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final generation = ++_loadGeneration;
    setState(() {
      _slots = null;
      _slotsError = null;
      _selectedSlot = null;
    });
    try {
      final slots = await FutsalApi.fetchSlots(widget.ground.id, _selectedDay);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _slots = slots);
    } on ApiException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _slotsError = e.message);
    }
  }

  void _selectDay(DateTime day) {
    if (day == _selectedDay) return;
    _selectedDay = day;
    _loadSlots();
  }

  Future<void> _book() async {
    final slot = _selectedSlot;
    if (slot == null) return;

    setState(() => _isBooking = true);
    try {
      final booking = await FutsalApi.createBooking(
        groundId: widget.ground.id,
        day: _selectedDay,
        startTime: slot.startTime,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 48),
          title: const Text('Booked!'),
          content: Text(
            '${widget.ground.name}\n${booking.dateLabel} · ${booking.timeLabel}\n\n'
            'Booking ref: ${booking.bookingRef}\nPay Rs ${booking.price.toStringAsFixed(0)} at the ground.',
            textAlign: TextAlign.center,
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      // Someone else got the slot first — show the up-to-date times.
      if (e.statusCode == 409) _loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ground = widget.ground;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(ground.name, style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _GroundSummary(ground: ground),
          const SizedBox(height: 24),
          Text('Pick a date', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          DateStrip(days: _days, selected: _selectedDay, onSelected: _selectDay),
          const SizedBox(height: 24),
          Text('Pick a time', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          _buildSlots(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.infoBannerBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: AppColors.infoBannerText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pay in cash at the ground.', style: TextStyle(color: AppColors.infoBannerText)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _selectedSlot == null || _isBooking ? null : _book,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isBooking
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _selectedSlot == null
                        ? 'Select a time'
                        : 'Book ${formatClock(_selectedSlot!.startTime)} · Rs ${_selectedSlot!.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlots() {
    if (_slotsError != null) {
      return Column(
        children: [
          Text(_slotsError!, style: AppTextStyles.body, textAlign: TextAlign.center),
          TextButton(onPressed: _loadSlots, child: const Text('Try again')),
        ],
      );
    }
    final slots = _slots;
    if (slots == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!slots.any((slot) => slot.available)) {
      return Text('No free slots on this day. Try another date.', style: AppTextStyles.body);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in slots)
          ChoiceChip(
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatClock(slot.startTime)),
                Text('Rs ${slot.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
              ],
            ),
            selected: _selectedSlot == slot,
            onSelected: slot.available ? (_) => setState(() => _selectedSlot = slot) : null,
            selectedColor: AppColors.primaryGreen,
            labelStyle: TextStyle(
              color: _selectedSlot == slot ? Colors.white : (slot.available ? AppColors.textPrimary : AppColors.textSecondary),
              decoration: slot.available ? null : TextDecoration.lineThrough,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _GroundSummary extends StatelessWidget {
  final GroundModel ground;

  const _GroundSummary({required this.ground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ground.address.isEmpty ? ground.area : '${ground.address}, ${ground.area}',
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Rate(label: 'Morning', hours: 'before ${formatClock('$dayStartsHour:00')}', price: ground.morningPrice,
                  isPeak: ground.peakPrice == ground.morningPrice),
              _Rate(label: 'Day', hours: '${formatClock('$dayStartsHour:00')} – ${formatClock('$eveningStartsHour:00')}',
                  price: ground.dayPrice, isPeak: ground.peakPrice == ground.dayPrice),
              _Rate(label: 'Evening', hours: 'from ${formatClock('$eveningStartsHour:00')}', price: ground.eveningPrice,
                  isPeak: ground.peakPrice == ground.eveningPrice),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the ground's three hourly rates; the highest is marked "Peak".
class _Rate extends StatelessWidget {
  final String label;
  final String hours;
  final double price;
  final bool isPeak;

  const _Rate({required this.label, required this.hours, required this.price, required this.isPeak});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
              if (isPeak) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.badgeOrangeBg, borderRadius: BorderRadius.circular(6)),
                  child: Text('Peak', style: TextStyle(fontSize: 10, color: AppColors.accentOrange,
                      fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text('Rs ${price.toStringAsFixed(0)}', style: AppTextStyles.price.copyWith(fontSize: 15)),
          Text(hours, style: AppTextStyles.caption.copyWith(fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
