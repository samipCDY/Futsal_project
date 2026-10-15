import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/admin_api.dart';
import '../../core/services/api_exception.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/ground_status_chip.dart';
import '../../core/widgets/profile_tab.dart';
import 'admin_ground_screen.dart';

/// Root shell for the admin: approve new grounds, and the Profile tab.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tabIndex = 0;

  static const _navItems = [
    NavItem(icon: Icons.fact_check_outlined, label: 'Approvals'),
    NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  final _tabs = const [_ApprovalsTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: AppBottomNavBar(
        items: _navItems,
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}

/// Counts of pending / approved / rejected grounds (tap one to list them)
/// and the grounds with that status, oldest first.
class _ApprovalsTab extends StatefulWidget {
  const _ApprovalsTab();

  @override
  State<_ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<_ApprovalsTab> {
  GroundStatus _status = GroundStatus.pending;
  Map<GroundStatus, int>? _counts;
  List<AdminGround>? _grounds;
  String? _error;
  final _search = TextEditingController();
  Timer? _searchDelay;

  /// Bumped on every load so a slow answer for another status or search
  /// can't replace the list now shown.
  int _loadGeneration = 0;

  String get _query => _search.text.trim();

  @override
  void initState() {
    super.initState();
    _load();
    AdminApi.groundsChanged.addListener(_load);
  }

  @override
  void dispose() {
    AdminApi.groundsChanged.removeListener(_load);
    _searchDelay?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Waits until the admin stops typing for a moment, then searches.
  void _onSearchChanged(String _) {
    _searchDelay?.cancel();
    setState(() => _grounds = null);
    _searchDelay = Timer(const Duration(milliseconds: 400), _load);
  }

  void _clearSearch() {
    _search.clear();
    FocusScope.of(context).unfocus();
    _onSearchChanged('');
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final query = _query;
    try {
      final results = await Future.wait([
        AdminApi.fetchCounts(),
        query.isEmpty ? AdminApi.fetchGrounds(_status) : AdminApi.searchGrounds(query),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _counts = results[0] as Map<GroundStatus, int>;
        _grounds = results[1] as List<AdminGround>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _select(GroundStatus status) {
    if (status == _status && _query.isEmpty) return;
    _search.clear();
    setState(() {
      _status = status;
      _grounds = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final grounds = _grounds;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Ground approvals', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
            const SizedBox(height: 4),
            Text('Check each lalpurja before customers can book the ground.', style: AppTextStyles.caption),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search ground, area, owner or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), tooltip: 'Clear', onPressed: _clearSearch),
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final status in GroundStatus.values) ...[
                  if (status != GroundStatus.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _CountCard(
                      status: status,
                      count: _counts?[status],
                      selected: status == _status && _query.isEmpty,
                      onTap: () => _select(status),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (_query.isNotEmpty) ...[
              Text('Results for "$_query" (all grounds)', style: AppTextStyles.caption),
              const SizedBox(height: 10),
            ],
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
                  _query.isNotEmpty
                      ? 'No ground matches "$_query".'
                      : _status == GroundStatus.pending
                          ? 'All caught up! No grounds waiting. 🎉'
                          : 'Nothing here yet.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final item in grounds) ...[
                _GroundTile(
                  item: item,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminGroundScreen(groundId: item.ground.id)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final GroundStatus status;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _CountCard({required this.status, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (colour, label) = switch (status) {
      GroundStatus.pending => (AppColors.statusPendingText, 'Pending'),
      GroundStatus.approved => (AppColors.primaryGreen, 'Approved'),
      GroundStatus.rejected => (AppColors.dangerText, 'Rejected'),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colour.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colour : AppColors.divider, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(count?.toString() ?? '–',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colour)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GroundTile extends StatelessWidget {
  final AdminGround item;
  final VoidCallback onTap;

  const _GroundTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ground = item.ground;
    final placeholder = Container(
      color: AppColors.primaryGreen.withValues(alpha: 0.85),
      child: const Icon(Icons.sports_soccer, color: Colors.white70),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: ground.imageUrl.isEmpty
                    ? placeholder
                    : CachedNetworkImage(imageUrl: ground.imageUrl, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => placeholder),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ground.name, style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${ground.area} · by ${item.ownerName.isEmpty ? item.ownerEmail : item.ownerName}',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text('Sent ${formatDateDayMonthYear(item.submittedAt)}', style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GroundStatusChip(status: ground.status),
                const SizedBox(height: 8),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
