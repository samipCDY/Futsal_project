import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/screens/send_notice_screen.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/owner_api.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/profile_avatar.dart';
import '../screens/ground_form_screen.dart';
import 'earnings_chart_card.dart';
import 'owner_booking_tile.dart';

/// The owner's at-a-glance page: today's and this week's numbers, and the
/// next few games at their grounds.
class OwnerDashboardTab extends StatefulWidget {
  /// Switches the home screen to the Bookings tab.
  final VoidCallback onOpenBookings;

  const OwnerDashboardTab({super.key, required this.onOpenBookings});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  OwnerSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    OwnerApi.groundsChanged.addListener(_load);
    FutsalApi.bookingsChanged.addListener(_load);
  }

  @override
  void dispose() {
    OwnerApi.groundsChanged.removeListener(_load);
    FutsalApi.bookingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final summary = await OwnerApi.fetchSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final summary = _summary;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                ProfileAvatar(photoUrl: profile?.avatarUrl ?? '', initials: profile?.initials ?? '', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${profile?.firstName ?? ''}', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                      Text("Here's how your grounds are doing", style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const NotificationBell(),
              ],
            ),
            const SizedBox(height: 20),
            if (summary == null && _error != null)
              Column(
                children: [
                  Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else if (summary == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (summary.totalGrounds == 0) ...[
                _AddFirstGroundCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroundFormScreen())),
                ),
                const SizedBox(height: 16),
              ],
              if (summary.rejectedGrounds > 0)
                _ApprovalBanner(
                  rejected: true,
                  text: '${summary.rejectedGrounds} ground${summary.rejectedGrounds == 1 ? ' was' : 's were'} '
                      'not approved. Open the Grounds tab to see why and fix it.',
                ),
              if (summary.pendingGrounds > 0)
                _ApprovalBanner(
                  rejected: false,
                  text: '${summary.pendingGrounds} ground${summary.pendingGrounds == 1 ? ' is' : 's are'} waiting '
                      'for approval. We check the lalpurja and you get an email once it is approved.',
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(icon: Icons.today, label: "Today's bookings", value: '${summary.todayBookings}'),
                  _StatCard(icon: Icons.date_range, label: 'This week', value: '${summary.weekBookings} bookings'),
                  _StatCard(icon: Icons.payments_outlined, label: "This week's earnings",
                      value: formatRupees(summary.weekEarnings)),
                  _StatCard(icon: Icons.sports_soccer, label: 'Live grounds',
                      value: '${summary.activeGrounds} of ${summary.totalGrounds}'),
                ],
              ),
              if (summary.totalGrounds > 0) ...[
                const SizedBox(height: 16),
                const EarningsChartCard(),
              ],
              const SizedBox(height: 12),
              if (summary.totalGrounds > 0)
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SendNoticeScreen())),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Message your customers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Upcoming games', style: AppTextStyles.subheading)),
                  TextButton(onPressed: widget.onOpenBookings, child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 4),
              if (summary.upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No upcoming bookings yet.', style: AppTextStyles.body, textAlign: TextAlign.center),
                )
              else
                for (final booking in summary.upcoming) ...[
                  OwnerBookingTile(booking: booking, showDate: true, showGround: summary.totalGrounds > 1),
                  const SizedBox(height: 12),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppTextStyles.heading.copyWith(fontSize: 20)),
              ),
              Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddFirstGroundCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFirstGroundCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusConfirmedBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add your first ground', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text('List your futsal ground so players nearby can find and book it.', style: AppTextStyles.body),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('Add ground'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  final bool rejected;
  final String text;

  const _ApprovalBanner({required this.rejected, required this.text});

  @override
  Widget build(BuildContext context) {
    final foreground = rejected ? AppColors.dangerText : AppColors.statusPendingText;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rejected ? AppColors.dangerBg : AppColors.statusPendingBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(rejected ? Icons.error_outline : Icons.hourglass_top, color: foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: foreground, fontSize: 13))),
        ],
      ),
    );
  }
}
