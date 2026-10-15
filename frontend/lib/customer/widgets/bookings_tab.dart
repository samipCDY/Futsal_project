import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import 'booking_card.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _segment = 0;
  List<BookingModel>? _bookings;
  String? _error;

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

  Future<void> _cancel(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text('${booking.groundName}\n${booking.dateLabel} · ${booking.timeLabel}'),
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
      await FutsalApi.cancelBooking(booking.id); // the listener reloads the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _segment == 0;
    final bookings = (_bookings ?? []).where((b) => b.isUpcoming == upcoming).toList();
    // The API sends newest first; upcoming games read better soonest first.
    if (upcoming) {
      bookings.sort((a, b) => a.date.compareTo(b.date) != 0
          ? a.date.compareTo(b.date)
          : a.startTime.compareTo(b.startTime));
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
              onChanged: (index) => setState(() => _segment = index),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_bookings == null && _error == null)
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

  static const _labels = ['Upcoming', 'History'];

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
