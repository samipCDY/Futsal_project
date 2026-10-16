import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/admin_api.dart';
import '../../core/services/api_exception.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/ground_status_chip.dart';
import '../../core/widgets/photo_gallery.dart';

/// Everything an admin needs to decide on one ground: the owner, where it
/// is, and the lalpurja photo. Approve or reject at the bottom.
class AdminGroundScreen extends StatefulWidget {
  final String groundId;

  const AdminGroundScreen({super.key, required this.groundId});

  @override
  State<AdminGroundScreen> createState() => _AdminGroundScreenState();
}

class _AdminGroundScreenState extends State<AdminGroundScreen> {
  AdminGround? _item;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final item = await AdminApi.fetchGround(widget.groundId);
      if (mounted) setState(() => _item = item);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _decide(Future<AdminGround> Function() decision, String done) async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await decision();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _approve() async {
    final ground = _item!.ground;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${ground.name}?'),
        content: const Text('Customers will be able to find and book it. The owner gets an email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed == true) {
      await _decide(() => AdminApi.approve(ground.id), '${ground.name} approved ✓');
    }
  }

  Future<void> _reject() async {
    final ground = _item!.ground;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(isLive: ground.status == GroundStatus.approved),
    );
    if (reason != null) {
      await _decide(() => AdminApi.reject(ground.id, reason), '${ground.name} rejected. The owner was told why.');
    }
  }

  void _openDocument(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _DocumentViewer(url: url)));
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(item?.ground.name ?? 'Ground', style: AppTextStyles.subheading),
      ),
      body: item == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
            )
          : RefreshIndicator(onRefresh: _load, child: _details(item)),
      bottomNavigationBar: item == null ? null : _decisionButtons(item.ground.status),
    );
  }

  Widget _details(AdminGround item) {
    final ground = item.ground;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (ground.photos.isNotEmpty) ...[
          PhotoCarousel(photos: ground.photos, height: 190),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(child: Text(ground.name, style: AppTextStyles.heading.copyWith(fontSize: 20))),
            GroundStatusChip(status: ground.status),
          ],
        ),
        const SizedBox(height: 4),
        Text('Sent for approval on ${formatDateDayMonthYear(item.submittedAt)}', style: AppTextStyles.caption),
        if (ground.status == GroundStatus.rejected && ground.reviewNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
            child: Text('Rejected because: ${ground.reviewNote}', style: TextStyle(color: AppColors.dangerText)),
          ),
        ],
        const SizedBox(height: 20),
        _Section(
          title: 'Lalpurja (ownership paper)',
          children: [
            Text('Check the name on it matches the owner below.', style: AppTextStyles.caption),
            const SizedBox(height: 10),
            if (item.documentUrl == null)
              Text("Couldn't load the photo. Pull down to try again.", style: AppTextStyles.body)
            else
              GestureDetector(
                onTap: () => _openDocument(item.documentUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Image.network(
                        item.documentUrl!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (_, __, ___) => SizedBox(
                          height: 80,
                          child: Center(child: Text("Couldn't load the photo.", style: AppTextStyles.body)),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _Section(
          title: 'Owner',
          children: [
            Text(item.ownerName.isEmpty ? '—' : item.ownerName, style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600)),
            if (item.ownerAddress.isNotEmpty) Text(item.ownerAddress, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (item.ownerPhone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => callNumber(context, item.ownerPhone),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(item.ownerPhone),
                  ),
                if (item.ownerEmail.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openOrCopy(context, Uri(scheme: 'mailto', path: item.ownerEmail), item.ownerEmail),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: Text(item.ownerEmail),
                  ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Location',
          children: [
            Text(ground.address.isEmpty ? ground.area : '${ground.address}, ${ground.area}', style: AppTextStyles.body),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/search/?api=1&query=${ground.latitude},${ground.longitude}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ],
        ),
        _Section(
          title: 'Hours and rates',
          children: [
            Text('Open ${formatTimeRange(ground.opensAt, ground.closesAt)}', style: AppTextStyles.body),
            const SizedBox(height: 4),
            Text(
              'Morning ${formatRupees(ground.morningPrice)} · Day ${formatRupees(ground.dayPrice)} · '
              'Evening ${formatRupees(ground.eveningPrice)}',
              style: AppTextStyles.body,
            ),
            if (ground.badgeLabel != null) ...[
              const SizedBox(height: 4),
              Text('Highlight: ${ground.badgeLabel}', style: AppTextStyles.caption),
            ],
          ],
        ),
      ],
    );
  }

  Widget _decisionButtons(GroundStatus status) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (status != GroundStatus.rejected)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    side: BorderSide(color: AppColors.dangerText),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(status == GroundStatus.approved ? 'Reject (violation)' : 'Reject',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            if (status == GroundStatus.pending) const SizedBox(width: 12),
            if (status != GroundStatus.approved)
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subheading.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Asks why the ground is rejected; the owner sees this reason.
class _RejectDialog extends StatefulWidget {
  /// Rejecting an approved ground (e.g. after a complaint) takes it off the app.
  final bool isLive;

  const _RejectDialog({required this.isLive});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  static const _checkReasons = [
    'Lalpurja photo is not clear',
    'Name on lalpurja does not match the owner',
    'Location on the map is wrong',
  ];

  static const _violationReasons = [
    'Customers reported this ground is fake',
    'Ground is closed or no longer exists',
    'Wrong prices or details shown',
    'Rude behaviour reported by customers',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isLive ? 'Take this ground down?' : 'Why reject it?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isLive
                ? 'Customers will no longer see or book it. Bookings already made stay. '
                    'The owner sees the reason and can fix it.'
                : 'The owner sees this and can fix it.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in widget.isLive ? _violationReasons : _checkReasons)
                  ActionChip(label: Text(reason, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _reason.text = reason)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLength: 255,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Reason', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()),
          style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
          child: Text(widget.isLive ? 'Take down' : 'Reject'),
        ),
      ],
    );
  }
}

/// Full-screen lalpurja photo with pinch-to-zoom, to read the small print.
class _DocumentViewer extends StatelessWidget {
  final String url;

  const _DocumentViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Lalpurja'),
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }
}
