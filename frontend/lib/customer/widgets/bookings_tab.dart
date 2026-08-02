import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import 'booking_card.dart';

const _mockBookings = [
  BookingModel(
    id: 'b1',
    bookingRef: '#FB-1042',
    groundName: 'Kathmandu Futsal Arena',
    status: BookingStatus.confirmed,
    dateLabel: 'Wed 15 Jul 2026',
    timeLabel: '6:00–7:00 PM',
    price: 1400,
    paymentMethod: 'Khalti',
  ),
  BookingModel(
    id: 'b2',
    bookingRef: '#FB-1055',
    groundName: 'New Baneshwor Futsal Hub',
    status: BookingStatus.pending,
    dateLabel: 'Sat 18 Jul 2026',
    timeLabel: '8:00–9:00 PM',
    price: 1200,
  ),
  BookingModel(
    id: 'b3',
    bookingRef: '#FB-0988',
    groundName: 'Kathmandu Futsal Arena',
    status: BookingStatus.completed,
    dateLabel: 'Sun 12 Jul 2026',
    timeLabel: '7:00–8:00 PM',
    price: 1400,
  ),
];

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final bookings = _mockBookings
        .where((b) => _segment == 0 ? b.status != BookingStatus.completed : b.status == BookingStatus.completed)
        .toList();

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final booking in bookings) ...[
                  BookingCard(booking: booking),
                  const SizedBox(height: 16),
                ],
              ],
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
