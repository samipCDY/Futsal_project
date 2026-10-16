import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/event_model.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/date_strip.dart';
import '../../core/widgets/event_card.dart';
import '../../core/widgets/photo_gallery.dart';
import '../widgets/ground_place_sheet.dart';
import '../widgets/ground_reviews.dart';
import '../widgets/slot_grid.dart';
import 'payment_screen.dart';

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
  String? _closedReason; // set when the ground is closed on the selected day
  String? _slotsError;
  List<EventModel> _events = [];
  Set<String> _methods = {'cash'}; // what the server offers
  String _method = 'cash';
  SlotModel? _selectedSlot;
  bool _isBooking = false;

  /// True until the first day's slots arrive; if today has nothing left to
  /// book (e.g. it's after closing time), the page moves on to tomorrow.
  bool _firstLoad = true;

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
    _loadEvents();
    _loadPaymentMethods();
  }

  /// If this fails, cash at the ground is still offered.
  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await FutsalApi.fetchPaymentMethods();
      if (mounted) setState(() => _methods = methods..add('cash'));
    } on ApiException {
      // ignore
    }
  }

  /// Optional extra: if events fail to load, the page just doesn't show them.
  Future<void> _loadEvents() async {
    try {
      final events = await FutsalApi.fetchEvents(groundId: widget.ground.id);
      if (mounted) setState(() => _events = events.where((event) => !event.isExpired).toList());
    } on ApiException {
      // ignore
    }
  }

  Future<void> _loadSlots() async {
    final generation = ++_loadGeneration;
    setState(() {
      _slots = null;
      _slotsError = null;
      _selectedSlot = null;
    });
    try {
      final day = await FutsalApi.fetchSlots(widget.ground.id, _selectedDay);
      if (!mounted || generation != _loadGeneration) return;
      final skipToday = _firstLoad && _selectedDay == _days.first && day.closedReason == null &&
          !day.slots.any((slot) => slot.available);
      _firstLoad = false;
      if (skipToday) {
        _selectedDay = _days[1];
        _loadSlots();
        return;
      }
      setState(() {
        _slots = day.slots;
        _closedReason = day.closedReason;
      });
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
      var (booking, payment) = await FutsalApi.createBooking(
        groundId: widget.ground.id,
        day: _selectedDay,
        startTime: slot.startTime,
        paymentMethod: _method,
      );
      if (!mounted) return;
      if (payment != null) {
        final paid = await payForBooking(context, booking.id, payment);
        if (!mounted) return;
        if (paid == null) {
          setState(() => _isBooking = false);
          _loadSlots();
          return;
        }
        booking = paid;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 48),
          title: const Text('Booked!'),
          content: Text(
            '${widget.ground.name}\n${booking.dateLabel} · ${booking.timeLabel}\n\n'
            'Booking ref: ${booking.bookingRef}\n'
            '${booking.isPaid ? 'Paid ${formatRupees(booking.price)} with ${booking.paymentLabel} ✓' : 'Pay ${formatRupees(booking.price)} at the ground.'}'
            '${booking.isPaid ? '\n\nFree cancellation for 2 hours, then 50% refund.' : ''}',
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
          if (ground.photos.isNotEmpty) ...[
            PhotoCarousel(photos: ground.photos, height: 200),
            const SizedBox(height: 12),
          ],
          _GroundSummary(ground: ground),
          for (final period in ground.maintenance) ...[
            const SizedBox(height: 12),
            _MaintenanceNotice(period: period),
          ],
          const SizedBox(height: 24),
          Text('Pick a date', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          DateStrip(days: _days, selected: _selectedDay, onSelected: _selectDay),
          const SizedBox(height: 24),
          Text('Pick a time', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          _buildSlots(),
          const SizedBox(height: 24),
          Text('How do you want to pay?', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          for (final (method, label, icon, colour) in [
            ('esewa', 'eSewa', Icons.account_balance_wallet_outlined, const Color(0xFF60BB46)),
            ('khalti', 'Khalti', Icons.account_balance_wallet_outlined, const Color(0xFF5C2D91)),
            ('cash', 'Cash at the ground', Icons.payments_outlined, AppColors.darkGreen),
          ])
            _PaymentOption(
              label: label,
              icon: icon,
              colour: colour,
              selected: _method == method,
              // Shown even when not set up yet, so customers know it's coming.
              onTap: _methods.contains(method) ? () => setState(() => _method = method) : null,
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.infoBannerBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.infoBannerText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _method == 'cash'
                        ? 'Pay in cash at the ground. You can cancel any time before the game starts.'
                        : 'Your slot is held for 15 minutes while you pay. Refunds go back to the same '
                            'account: full within 2 hours of booking, later 50%.',
                    style: TextStyle(color: AppColors.infoBannerText),
                  ),
                ),
              ],
            ),
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Events at this ground', style: AppTextStyles.subheading),
            const SizedBox(height: 12),
            for (final event in _events) ...[
              EventCard(event: event, showGround: false),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 24),
          GroundReviewsSection(groundId: ground.id, groundName: ground.name),
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
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _selectedSlot == null
                        ? 'Select a time'
                        : _method == 'cash'
                            ? 'Book ${formatClock(_selectedSlot!.startTime)} · ${formatRupees(_selectedSlot!.price)}'
                            : 'Pay ${formatRupees(_selectedSlot!.price)} with ${_method == 'khalti' ? 'Khalti' : 'eSewa'}',
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
    if (_closedReason != null) {
      return Text('Closed for maintenance this day: $_closedReason. Please pick another date.',
          style: AppTextStyles.body.copyWith(color: AppColors.statusPendingText));
    }
    if (!slots.any((slot) => slot.available)) {
      return Text('No free slots on this day. Try another date.', style: AppTextStyles.body);
    }
    return SlotGrid(
      slots: slots,
      selected: _selectedSlot,
      onSelect: (slot) => setState(() => _selectedSlot = slot),
    );
  }
}

class _GroundSummary extends StatelessWidget {
  final GroundModel ground;

  const _GroundSummary({required this.ground});

  /// "10 AM", short enough that the three rates never wrap.
  static String _hour(int hour) => '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}';

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
              Expanded(child: RatingLine(rating: ground.rating, count: ground.reviewCount)),
              TextButton.icon(
                onPressed: () => openDirections(context, ground.latitude, ground.longitude),
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Directions'),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rate(
                  label: 'Morning',
                  hours: 'before ${_hour(dayStartsHour)}',
                  price: ground.morningPrice,
                  isPeak: ground.peakPrice == ground.morningPrice),
              _Rate(
                  label: 'Day',
                  hours: '${_hour(dayStartsHour)} – ${_hour(eveningStartsHour)}',
                  price: ground.dayPrice,
                  isPeak: ground.peakPrice == ground.dayPrice),
              _Rate(
                  label: 'Evening',
                  hours: 'from ${_hour(eveningStartsHour)}',
                  price: ground.eveningPrice,
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
                  child: Text('Peak',
                      style: TextStyle(fontSize: 10, color: AppColors.accentOrange, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(formatRupees(price), style: AppTextStyles.price.copyWith(fontSize: 15)),
          Text(hours, style: AppTextStyles.caption.copyWith(fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// "Closed for maintenance 20 – 22 Oct: Replacing the turf".
class _MaintenanceNotice extends StatelessWidget {
  final MaintenancePeriod period;

  const _MaintenanceNotice({required this.period});

  @override
  Widget build(BuildContext context) {
    final days = period.isOneDay
        ? formatDateLong(period.startsOn)
        : '${formatDateShort(period.startsOn)} – ${formatDateLong(period.endsOn)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.statusPendingBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.construction, color: AppColors.statusPendingText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Closed for maintenance: $days\n${period.reason}',
              style: TextStyle(color: AppColors.statusPendingText),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color colour;
  final bool selected;
  final VoidCallback? onTap; // null = not available yet

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: available ? 1 : 0.5,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colour.withValues(alpha: 0.1) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? colour : AppColors.divider, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: colour),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600))),
                if (available)
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? colour : AppColors.textSecondary)
                else
                  Text('Coming soon', style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
