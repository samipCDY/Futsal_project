import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/money.dart';

/// One booking as the ground owner sees it: when, who (with a call button),
/// and how much.
class OwnerBookingTile extends StatelessWidget {
  final BookingModel booking;
  final bool showDate;
  final bool showGround;
  final VoidCallback? onCancel;

  const OwnerBookingTile({
    super.key,
    required this.booking,
    this.showDate = false,
    this.showGround = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final phone = booking.customerPhone ?? '';
    final isCancelled = booking.status == BookingStatus.cancelled;

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
              Icon(Icons.schedule, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  showDate ? '${booking.dateLabel} · ${booking.timeLabel}' : booking.timeLabel,
                  style: AppTextStyles.subheading.copyWith(
                    fontSize: 15,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              _StatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(booking.customerName ?? 'Customer', style: AppTextStyles.body)),
              if (phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => callNumber(context, phone),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(phone),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
            ],
          ),
          if (showGround) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.sports_soccer, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(booking.groundName, style: AppTextStyles.body),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(formatRupees(booking.price), style: AppTextStyles.price.copyWith(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                  booking.isPayAtGround
                      ? '· cash at ground'
                      : booking.isPaid
                          ? '· paid via ${booking.paymentLabel}'
                          : '· waiting for ${booking.paymentLabel} payment',
                  style: AppTextStyles.caption),
              const Spacer(),
              Text(booking.bookingRef, style: AppTextStyles.caption),
            ],
          ),
          if (isCancelled && booking.refundAmount != null) ...[
            const SizedBox(height: 6),
            Text(
              !booking.isPaid
                  ? '${booking.cancelledBy == 'owner' ? 'You' : 'Customer'} cancelled · nothing was paid'
                  : booking.cancelledBy == 'owner'
                      ? 'You cancelled · full refund ${formatRupees(booking.refundAmount!)}'
                      : 'Customer cancelled · refund ${formatRupees(booking.refundAmount!)}'
                          ' · you keep ${formatRupees(booking.ownerKeeps)}',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            if (booking.cancelReason.isNotEmpty) Text(booking.cancelReason, style: AppTextStyles.caption),
          ],
          if (onCancel != null && booking.isUpcoming) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.dangerBg,
                  foregroundColor: AppColors.dangerText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel booking', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BookingStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (background, foreground, label) = switch (status) {
      BookingStatus.confirmed => (AppColors.statusConfirmedBg, AppColors.statusConfirmedText, 'CONFIRMED'),
      BookingStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'PENDING'),
      BookingStatus.completed => (AppColors.statusCompletedBg, AppColors.statusCompletedText, 'PLAYED'),
      BookingStatus.cancelled => (AppColors.dangerBg, AppColors.dangerText, 'CANCELLED'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
