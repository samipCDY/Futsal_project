import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/services/admin_api.dart';
import '../../core/services/api_exception.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/money.dart';

/// Refunds of eSewa/Khalti payments. The admin sends the money back in the
/// gateway's merchant portal, then marks it sent here (the customer is told).
class AdminRefundsTab extends StatefulWidget {
  const AdminRefundsTab({super.key});

  @override
  State<AdminRefundsTab> createState() => _AdminRefundsTabState();
}

class _AdminRefundsTabState extends State<AdminRefundsTab> {
  bool _showSent = false;
  List<BookingModel>? _refunds;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final refunds = await AdminApi.fetchRefunds(sent: _showSent);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _refunds = refunds;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _switch(bool showSent) {
    if (showSent == _showSent) return;
    setState(() {
      _showSent = showSent;
      _refunds = null;
    });
    _load();
  }

  Future<void> _markSent(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund sent?'),
        content: Text(
          'Only tap "Yes, sent" after sending ${formatRupees(booking.refundAmount ?? 0)} back to '
          '${booking.customerName ?? 'the customer'} in the ${booking.paymentLabel} merchant portal.\n\n'
          '${booking.paymentLabel} transaction: ${booking.paymentTxnId}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, sent')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AdminApi.markRefunded(booking.id);
      messenger.showSnackBar(const SnackBar(content: Text('Marked as refunded. The customer was told.')));
      _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final refunds = _refunds;
    final total = (refunds ?? []).fold<double>(0, (sum, b) => sum + (b.refundAmount ?? 0));
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Refunds', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
            const SizedBox(height: 4),
            Text('Send these back in the eSewa / Khalti merchant portal, then mark them sent.',
                style: AppTextStyles.caption),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('To send'), icon: Icon(Icons.hourglass_top)),
                ButtonSegment(value: true, label: Text('Sent'), icon: Icon(Icons.check)),
              ],
              selected: {_showSent},
              onSelectionChanged: (selection) => _switch(selection.first),
            ),
            const SizedBox(height: 12),
            if (refunds != null && refunds.isNotEmpty && !_showSent)
              Text('${refunds.length} to send · ${formatRupees(total)}',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (refunds == null && _error != null)
              Column(
                children: [
                  Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else if (refunds == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (refunds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(_showSent ? 'No refunds sent yet.' : 'No refunds waiting. 🎉',
                    style: AppTextStyles.body, textAlign: TextAlign.center),
              )
            else
              for (final booking in refunds) ...[
                _RefundTile(booking: booking, onMarkSent: _showSent ? null : () => _markSent(booking)),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _RefundTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onMarkSent;

  const _RefundTile({required this.booking, this.onMarkSent});

  @override
  Widget build(BuildContext context) {
    final phone = booking.customerPhone ?? '';
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
              Expanded(
                child: Text(formatRupees(booking.refundAmount ?? 0),
                    style: AppTextStyles.price.copyWith(fontSize: 20)),
              ),
              Text('of ${formatRupees(booking.price)} · ${booking.paymentLabel}', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 6),
          Text('${booking.customerName ?? 'Customer'} · ${booking.groundName}', style: AppTextStyles.body),
          Text('${booking.dateLabel} · ${booking.timeLabel}', style: AppTextStyles.caption),
          Text('${booking.paymentLabel} transaction: ${booking.paymentTxnId} · ${booking.bookingRef}',
              style: AppTextStyles.caption),
          Text(
            booking.cancelledBy == 'owner' ? 'Cancelled by the ground' : 'Cancelled by the customer',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => callNumber(context, phone),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(phone),
                ),
              const Spacer(),
              if (onMarkSent != null)
                ElevatedButton(
                  onPressed: onMarkSent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Mark sent'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
