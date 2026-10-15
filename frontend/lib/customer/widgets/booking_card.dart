import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const BookingCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isCompleted = booking.status == BookingStatus.completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.completedCardBg : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(status: booking.status),
              const Spacer(),
              if (!isCompleted)
                _RefChip(bookingRef: booking.bookingRef)
              else
                Icon(Icons.check_circle, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Text(booking.groundName, style: AppTextStyles.subheading.copyWith(fontSize: 17)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isCompleted ? Icons.history : Icons.calendar_today_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text('${booking.dateLabel} · ${booking.timeLabel}', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          _BookingBody(booking: booking, onCancel: onCancel),
        ],
      ),
    );
  }
}

class _BookingBody extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const _BookingBody({required this.booking, this.onCancel});

  Widget _priceRow() {
    if (booking.isPayAtGround) {
      return Row(
        children: [
          Text('Rs ${booking.price.toStringAsFixed(0)}', style: AppTextStyles.price),
          const SizedBox(width: 8),
          Text('Pay at the ground', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ],
      );
    }
    return Row(
      children: [
        Text('Rs ${booking.price.toStringAsFixed(0)}', style: AppTextStyles.price),
        const SizedBox(width: 8),
        Text('Paid via', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.khaltiPurple,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            booking.paymentLabel,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (booking.status) {
      case BookingStatus.confirmed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _priceRow(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.directions, size: 18, color: Colors.white),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reschedule'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _WideActionButton(label: 'Cancel Booking', onTap: onCancel),
          ],
        );

      case BookingStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _priceRow(),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoBannerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.infoBannerText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Waiting for arena confirmation...',
                      style: TextStyle(color: AppColors.infoBannerText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _WideActionButton(label: 'Cancel Booking', onTap: onCancel),
          ],
        );

      case BookingStatus.completed:
        return Column(
          children: [
            Text('How was your game?', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            const _StarRating(initialRating: 0),
          ],
        );

      case BookingStatus.cancelled:
        return Text(
          'Cancelled · Rs ${booking.price.toStringAsFixed(0)}',
          style: TextStyle(color: AppColors.textSecondary),
        );
    }
  }
}

class _WideActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _WideActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.dangerBg,
          foregroundColor: AppColors.dangerText,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label, icon) = switch (status) {
      BookingStatus.confirmed => (
          AppColors.statusConfirmedBg,
          AppColors.statusConfirmedText,
          'CONFIRMED',
          null,
        ),
      BookingStatus.pending => (
          AppColors.statusPendingBg,
          AppColors.statusPendingText,
          'PENDING',
          Icons.autorenew,
        ),
      BookingStatus.completed => (
          AppColors.statusCompletedBg,
          AppColors.statusCompletedText,
          'COMPLETED',
          null,
        ),
      BookingStatus.cancelled => (
          AppColors.dangerBg,
          AppColors.dangerText,
          'CANCELLED',
          null,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  final String bookingRef;

  const _RefChip({required this.bookingRef});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.refChipBg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        bookingRef,
        style: TextStyle(color: AppColors.refChipText, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StarRating extends StatefulWidget {
  final int initialRating;

  const _StarRating({required this.initialRating});

  @override
  State<_StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<_StarRating> {
  late int _rating = widget.initialRating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final filled = index < _rating;
        return IconButton(
          onPressed: () => setState(() => _rating = index + 1),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: AppColors.rating,
            size: 28,
          ),
        );
      }),
    );
  }
}
