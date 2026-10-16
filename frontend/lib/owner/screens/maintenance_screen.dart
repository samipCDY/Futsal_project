import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/owner_api.dart';
import '../../core/utils/time_format.dart';

/// Close a ground for some days (with a reason customers see), or reopen it.
class MaintenanceScreen extends StatefulWidget {
  final GroundModel ground;

  const MaintenanceScreen({super.key, required this.ground});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late List<MaintenancePeriod> _periods = widget.ground.maintenance;
  final _reason = TextEditingController();
  DateTimeRange? _days;
  bool _isSaving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Fetches the ground again so the list shows what was saved.
  Future<void> _reload() async {
    try {
      final grounds = await OwnerApi.fetchMyGrounds();
      final ground = grounds.where((g) => g.id == widget.ground.id).firstOrNull;
      if (mounted && ground != null) setState(() => _periods = ground.maintenance);
    } on ApiException {
      // keep showing the old list
    }
  }

  Future<void> _pickDays() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _days,
      helpText: 'Days the ground is closed',
    );
    if (picked != null) setState(() => _days = picked);
  }

  String _daysLabel(DateTime first, DateTime last) => first == last
      ? formatDateLong(first)
      : '${formatDateShort(first)} – ${formatDateLong(last)}';

  Future<void> _close() async {
    final days = _days;
    final reason = _reason.text.trim();
    if (days == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick the days and write a reason customers will see.'),
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close the ground?'),
        content: Text(
          '${widget.ground.name} will be closed ${_daysLabel(days.start, days.end)}.\n\n'
          'Everyone already booked on these days is cancelled and gets a FULL refund (paid by you), '
          'and they get a notification with your reason.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Close ground'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cancelled = await OwnerApi.closeGround(widget.ground.id, days.start, days.end, reason);
      messenger.showSnackBar(SnackBar(
        content: Text(cancelled == 0
            ? 'Ground closed for those days.'
            : 'Ground closed. $cancelled booking${cancelled == 1 ? '' : 's'} cancelled with a full refund.'),
      ));
      _reason.clear();
      setState(() => _days = null);
      await _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _reopen(MaintenancePeriod period) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OwnerApi.reopenGround(period.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('Ground reopened for those days. Cancelled bookings stay cancelled.'),
      ));
      await _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Maintenance · ${widget.ground.name}', style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_periods.isNotEmpty) ...[
            Text('Closed days', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            for (final period in _periods)
              Card(
                color: AppColors.statusPendingBg,
                elevation: 0,
                child: ListTile(
                  leading: Icon(Icons.construction, color: AppColors.statusPendingText),
                  title: Text(_daysLabel(period.startsOn, period.endsOn),
                      style: TextStyle(color: AppColors.statusPendingText, fontWeight: FontWeight.w700)),
                  subtitle: Text(period.reason, style: TextStyle(color: AppColors.statusPendingText)),
                  trailing: TextButton(onPressed: () => _reopen(period), child: const Text('Reopen')),
                ),
              ),
            const SizedBox(height: 24),
          ],
          Text('Close the ground', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text('For turf repair, cleaning or any other work. Customers see the reason on the booking page.',
              style: AppTextStyles.caption),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDays,
            borderRadius: BorderRadius.circular(6),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Days',
                prefixIcon: Icon(Icons.date_range),
                border: OutlineInputBorder(),
              ),
              child: Text(days == null ? 'Tap to pick' : _daysLabel(days.start, days.end),
                  style: TextStyle(color: days == null ? AppColors.primaryGreen : AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason (customers see this)',
              hintText: 'e.g. Replacing the turf',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.infoBannerBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Bookings on these days are cancelled automatically, and those customers get a full refund.',
              style: TextStyle(color: AppColors.infoBannerText),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _close,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Close ground for these days', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
