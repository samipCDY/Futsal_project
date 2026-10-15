import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/owner_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../screens/ground_form_screen.dart';
import 'ground_status_chip.dart';

/// The owner's grounds: add new ones, edit them, show or hide them.
class OwnerGroundsTab extends StatefulWidget {
  const OwnerGroundsTab({super.key});

  @override
  State<OwnerGroundsTab> createState() => _OwnerGroundsTabState();
}

class _OwnerGroundsTabState extends State<OwnerGroundsTab> {
  List<GroundModel>? _grounds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    OwnerApi.groundsChanged.addListener(_load);
  }

  @override
  void dispose() {
    OwnerApi.groundsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final grounds = await OwnerApi.fetchMyGrounds();
      if (!mounted) return;
      setState(() {
        _grounds = grounds;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _openForm([GroundModel? ground]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroundFormScreen(ground: ground)));
  }

  Future<void> _setActive(GroundModel ground, bool active) async {
    try {
      await OwnerApi.saveGround({'is_active': active}, groundId: ground.id); // reloads the list
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!active
            ? '${ground.name} is hidden.'
            : ground.status == GroundStatus.approved
                ? '${ground.name} is visible to customers.'
                : '${ground.name} will show to customers once approved.'),
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grounds = _grounds;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add ground'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Text('My Grounds', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
              const SizedBox(height: 16),
              if (grounds == null && _error != null)
                Column(
                  children: [
                    Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ],
                )
              else if (grounds == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (grounds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    "You haven't added a ground yet.\nTap \"Add ground\" to list your first one.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final ground in grounds) ...[
                  _OwnerGroundCard(
                    ground: ground,
                    onEdit: () => _openForm(ground),
                    onActiveChanged: (active) => _setActive(ground, active),
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerGroundCard extends StatelessWidget {
  final GroundModel ground;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  const _OwnerGroundCard({required this.ground, required this.onEdit, required this.onActiveChanged});

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen.withValues(alpha: 0.85), AppColors.darkGreen],
        ),
      ),
      child: const Center(child: Icon(Icons.sports_soccer, size: 48, color: Colors.white24)),
    );

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Opacity(
                opacity: ground.isLive ? 1 : 0.45,
                child: ground.imageUrl.isEmpty
                    ? placeholder
                    : CachedNetworkImage(imageUrl: ground.imageUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => placeholder),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(ground.name, style: AppTextStyles.subheading.copyWith(fontSize: 17))),
                      GroundStatusChip(status: ground.status),
                      TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16), label: const Text('Edit')),
                    ],
                  ),
                  Text(
                    '${ground.area} · Open ${formatTimeRange(ground.opensAt, ground.closesAt)}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Morning ${formatRupees(ground.morningPrice)} · Day ${formatRupees(ground.dayPrice)}'
                    ' · Evening ${formatRupees(ground.eveningPrice)}',
                    style: AppTextStyles.caption,
                  ),
                  if (ground.status != GroundStatus.approved) ...[
                    const SizedBox(height: 10),
                    _ReviewMessage(ground: ground),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ground.isLive
                              ? 'Visible to customers'
                              : ground.isActive
                                  ? 'Customers will see it once approved'
                                  : 'Hidden from customers',
                          style: AppTextStyles.body.copyWith(
                            color: ground.isLive ? AppColors.primaryGreen : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: ground.isActive,
                        activeThumbColor: AppColors.primaryGreen,
                        onChanged: onActiveChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a ground isn't live yet: waiting for the admin, or what to fix.
class _ReviewMessage extends StatelessWidget {
  final GroundModel ground;

  const _ReviewMessage({required this.ground});

  @override
  Widget build(BuildContext context) {
    final rejected = ground.status == GroundStatus.rejected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rejected ? AppColors.dangerBg : AppColors.statusPendingBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        rejected
            ? 'Not approved: ${ground.reviewNote}\nTap Edit, fix it and save to send it again.'
            : 'Our team is checking your lalpurja. Customers will see this ground once it is approved.',
        style: TextStyle(color: rejected ? AppColors.dangerText : AppColors.statusPendingText, fontSize: 13),
      ),
    );
  }
}
