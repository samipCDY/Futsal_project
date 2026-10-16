import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import 'ground_place_sheet.dart';
import 'ground_reviews.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  /// Opens eSewa/Khalti again for a booking still waiting for payment.
  final VoidCallback? onPay;

  const BookingCard({super.key, required this.booking, this.onCancel, this.onPay});

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
          _BookingBody(booking: booking, onCancel: onCancel, onPay: onPay),
        ],
      ),
    );
  }
}

class _BookingBody extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  final VoidCallback? onPay;

  const _BookingBody({required this.booking, this.onCancel, this.onPay});

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
        Text(booking.isPaid ? 'Paid via' : 'Not paid yet ·', style: TextStyle(color: AppColors.textSecondary)),
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
                    onPressed: booking.groundLatitude == null
                        ? null
                        : () => openDirections(context, booking.groundLatitude!, booking.groundLongitude!),
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
            if (booking.isPaid && booking.freeCancelUntil != null) ...[
              const SizedBox(height: 6),
              Text(
                booking.isFreeToCancel
                    ? 'Free cancellation until ${formatClockOf(booking.freeCancelUntil!)} · then 50% refund'
                    : 'Cancelling now refunds 50% (${formatRupees(booking.refundIfCancelledNow ?? 0)})',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
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
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.infoBannerText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.paymentDueBy == null
                          ? 'Waiting for payment...'
                          : 'Waiting for payment · slot held until ${formatClockOf(booking.paymentDueBy!)}',
                      style: TextStyle(color: AppColors.infoBannerText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (onPay != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Pay now with ${booking.paymentLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _WideActionButton(label: 'Cancel Booking', onTap: onCancel),
          ],
        );

      case BookingStatus.completed:
        return Column(
          children: [
            Text('How was your game?', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            _RateGround(booking: booking),
          ],
        );

      case BookingStatus.cancelled:
        final refund = booking.refundAmount;
        final byGround = booking.cancelledBy == 'owner';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              byGround ? 'Cancelled by the ground' : 'Cancelled by you',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            if (byGround && booking.cancelReason.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(booking.cancelReason, style: TextStyle(color: AppColors.textSecondary)),
            ],
            if (refund != null && refund > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Refund ${formatRupees(refund)} of ${formatRupees(booking.price)}'
                ' (${(refund / booking.price * 100).round()}%)',
                style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
              ),
              if (booking.refundStatus == 'pending')
                Text('Being sent back to your ${booking.paymentLabel} account',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              else if (booking.refundStatus == 'done')
                Text('Refunded to your ${booking.paymentLabel} account ✓',
                    style: TextStyle(color: AppColors.primaryGreen, fontSize: 13)),
            ],
          ],
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

/// Five stars that open the review sheet for the ground, starting from the
/// stars tapped (or the customer's earlier review).
class _RateGround extends StatelessWidget {
  final BookingModel booking;

  const _RateGround({required this.booking});

  Future<void> _rate(BuildContext context, int stars) async {
    try {
      final reviews = await FutsalApi.fetchReviews(booking.groundId);
      if (!context.mounted) return;
      await showWriteReviewSheet(context,
          groundId: booking.groundId,
          groundName: booking.groundName,
          existing: reviews.myReview,
          stars: stars);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var stars = 1; stars <= 5; stars++)
          IconButton(
            tooltip: 'Rate $stars star${stars == 1 ? '' : 's'}',
            onPressed: () => _rate(context, stars),
            icon: Icon(Icons.star_outline_rounded, color: AppColors.rating, size: 30),
          ),
      ],
    );
  }
}
