import 'package:flutter/material.dart';
import '../screens/reschedule_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/models/event_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/event_card.dart';
import '../screens/payment_screen.dart';
import 'booking_card.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

const _eventsSegment = 2;

class _BookingsTabState extends State<BookingsTab> {
  int _segment = 0;
  List<BookingModel>? _bookings;
  String? _error;
  List<EventModel>? _events;
  String? _eventsError;

  @override
  void initState() {
    super.initState();
    _load();
    FutsalApi.bookingsChanged.addListener(_load);
  }

  @override
  void dispose() {
    FutsalApi.bookingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bookings = await FutsalApi.fetchMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await FutsalApi.fetchEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _eventsError = e.message);
    }
  }

  void _selectSegment(int index) {
    setState(() => _segment = index);
    if (index == _eventsSegment) _loadEvents();
  }

  Future<void> _pay(BookingModel booking) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final start = await FutsalApi.payBooking(booking.id);
      if (!mounted) return;
      final paid = await payForBooking(context, booking.id, start);
      if (paid != null) {
        messenger.showSnackBar(SnackBar(content: Text('Paid with ${paid.paymentLabel}. Booking confirmed! ✓')));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  /// "You'll get Rs 1,500 back (full amount)..." for the cancel dialog.
  String _refundText(BookingModel booking) {
    if (!booking.isPaid) return "Nothing has been paid yet, so there's nothing to refund.";
    final refund = booking.refundIfCancelledNow ?? booking.price;
    final where = booking.isPaid ? ' to your ${booking.paymentLabel} account' : '';
    if (booking.isFreeToCancel) {
      final until = booking.freeCancelUntil;
      return 'You get the full ${formatRupees(refund)} back$where'
          '${until == null ? '' : ' (free cancellation until ${formatClockOf(until)})'}.';
    }
    return 'More than 2 hours have passed since you booked, so you get 50% back$where: '
        '${formatRupees(refund)} of ${formatRupees(booking.price)}.';
  }

  Future<void> _cancel(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text('${booking.groundName}\n${booking.dateLabel} · ${booking.timeLabel}\n\n'
            '${_refundText(booking)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final cancelled = await FutsalApi.cancelBooking(booking.id); // the listener reloads the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((cancelled.refundAmount ?? 0) == 0
              ? 'Booking cancelled.'
              : 'Booking cancelled. Refund: ${formatRupees(cancelled.refundAmount!)}.'),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _eventsList() {
    final events = _events;
    if (events == null && _eventsError != null) {
      return Column(
        children: [
          Text(_eventsError!, style: AppTextStyles.body, textAlign: TextAlign.center),
          TextButton(onPressed: _loadEvents, child: const Text('Try again')),
        ],
      );
    }
    if (events == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text('No events right now. Tournaments posted by grounds show up here.',
            style: AppTextStyles.body, textAlign: TextAlign.center),
      );
    }
    return Column(
      children: [
        for (final event in events) ...[
          EventCard(event: event),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _segment == 0;
    final bookings = (_bookings ?? []).where((b) => b.isUpcoming == upcoming).toList();
    // The API sends newest first; upcoming games read better soonest first.
    if (upcoming) {
      bookings.sort(
          (a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.startTime.compareTo(b.startTime));
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text('My Bookings', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SegmentedTabs(
              selectedIndex: _segment,
              onChanged: _selectSegment,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _segment == _eventsSegment ? _loadEvents : _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_segment == _eventsSegment)
                    _eventsList()
                  else if (_bookings == null && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_bookings == null)
                    Column(
                      children: [
                        Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    )
                  else if (bookings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        upcoming ? 'No upcoming bookings. Find a ground on the Home tab!' : 'No past bookings yet.',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final booking in bookings) ...[
                      BookingCard(
                        booking: booking,
                        onCancel: booking.isUpcoming ? () => _cancel(booking) : null,
                        onPay: booking.isAwaitingPayment ? () => _pay(booking) : null,
                        onReschedule: booking.status == BookingStatus.confirmed
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RescheduleScreen(booking: booking)),
                                )
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.selectedIndex, required this.onChanged});

  static const _labels = ['Upcoming', 'History', 'Events'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final isSelected = index == selectedIndex;
        return Padding(
          padding: const EdgeInsets.only(right: 28),
          child: GestureDetector(
            onTap: () => onChanged(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labels[index],
                  style: AppTextStyles.subheading.copyWith(
                    color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  width: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
