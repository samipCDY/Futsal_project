import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Booking, refund, maintenance and event rules for customers and owners.
/// Keep the numbers in step with backend/bookings/models.py.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Rules & regulations', style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _RefundTable(),
          SizedBox(height: 16),
          _RuleSection(
            icon: Icons.event_available_outlined,
            title: 'Booking',
            rules: [
              'Grounds are booked by the hour. You can book up to 30 days ahead.',
              'Prices change by time of day: morning (before 10 AM), day (10 AM – 4 PM) and evening '
                  '(from 4 PM, the peak time).',
              'Pay at the ground before you play. Please arrive on time; the hour ends on time.',
              "A booking can't be cancelled once its hour has started.",
            ],
          ),
          _RuleSection(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Online payment (eSewa / Khalti)',
            rules: [
              'Pay online with eSewa or Khalti, or in cash at the ground.',
              'An online booking holds the slot for 15 minutes while you pay. If payment is not finished in '
                  'time, the slot is released and nothing is charged.',
              'The booking is confirmed only after eSewa or Khalti confirms the payment.',
              'Refunds for online payments go back to the same eSewa or Khalti account.',
            ],
          ),
          _RuleSection(
            icon: Icons.currency_exchange,
            title: 'Cancellation and refund',
            rules: [
              'Refunds are for bookings paid online with eSewa or Khalti.',
              'Cancel within 2 hours of booking: you get 100% back.',
              'Cancel later (but before the game starts): you get 50% back. The ground owner keeps the other '
                  '50% for holding the slot.',
              'If the ground owner cancels your booking, you always get 100% back.',
              'Cash bookings are paid at the ground, so cancelling one costs nothing.',
              'The exact refund is shown before you confirm a cancellation.',
            ],
          ),
          _RuleSection(
            icon: Icons.construction,
            title: 'Ground maintenance',
            rules: [
              'Owners can close a ground for maintenance and must say why. Customers see the notice on the '
                  'booking page.',
              'Everyone already booked on those days is cancelled automatically and gets a notification with '
                  'the reason. Those who paid online get a 100% refund.',
              'Maintenance refunds are always paid by the ground owner.',
            ],
          ),
          _RuleSection(
            icon: Icons.storefront_outlined,
            title: 'For ground owners',
            rules: [
              'Every new ground needs a clear photo of its lalpurja and is checked by our team before customers '
                  'can see it.',
              'Changing the name, area, address, location or lalpurja sends the ground for checking again.',
              'Earnings include the full price of games played and 50% of late cancellations paid online.',
              'Grounds that break the rules (fake listings, wrong details, poor behaviour) can be taken down.',
            ],
          ),
          _RuleSection(
            icon: Icons.emoji_events_outlined,
            title: 'Events and tournaments',
            rules: [
              'Owners can post events for their own grounds with a date and time. Drafts are only seen by the '
                  'owner until published.',
              'Published events are seen by everyone. They show as "Expired" once the date has passed.',
              'Customers who saved a ground get a notification when it posts a new event.',
            ],
          ),
        ],
      ),
    );
  }
}

/// The refund rules at a glance.
class _RefundTable extends StatelessWidget {
  const _RefundTable();

  @override
  Widget build(BuildContext context) {
    Widget row(String when, String refund, Color colour) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(when, style: AppTextStyles.body)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colour.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(refund, style: TextStyle(color: colour, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Refund at a glance (eSewa / Khalti)', style: AppTextStyles.subheading),
          const SizedBox(height: 8),
          row('Cancelled within 2 hours of booking', '100%', AppColors.primaryGreen),
          Divider(color: AppColors.divider, height: 1),
          row('Cancelled after 2 hours, before the game', '50%', AppColors.statusPendingText),
          Divider(color: AppColors.divider, height: 1),
          row('Cancelled by the ground / maintenance', '100%', AppColors.primaryGreen),
          Divider(color: AppColors.divider, height: 1),
          row('After the game has started', 'No cancel', AppColors.dangerText),
        ],
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> rules;

  const _RuleSection({required this.icon, required this.title, required this.rules});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.subheading.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppTextStyles.body),
                  Expanded(child: Text(rule, style: AppTextStyles.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
