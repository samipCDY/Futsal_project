import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/ground_model.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/owner_api.dart';

/// Write a message that lands under people's bell. Owners reach their own
/// customers; the admin reaches customers, owners or everyone.
class SendNoticeScreen extends StatefulWidget {
  final bool asAdmin;

  const SendNoticeScreen({super.key, this.asAdmin = false});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  late String _audience = widget.asAdmin ? 'customers' : 'upcoming';
  List<GroundModel> _grounds = [];
  String? _groundId; // null = all the owner's grounds
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (!widget.asAdmin) _loadGrounds();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadGrounds() async {
    try {
      final grounds = await OwnerApi.fetchMyGrounds();
      if (mounted) setState(() => _grounds = grounds);
    } on ApiException {
      // "All my grounds" still works without the list
    }
  }

  List<(String, String, String)> get _audiences => widget.asAdmin
      ? const [
          ('customers', 'All customers', 'Everyone who books grounds'),
          ('owners', 'All ground owners', 'Every owner on Futsal Finder'),
          ('everyone', 'Everyone', 'Customers and owners'),
        ]
      : const [
          ('upcoming', 'Customers with upcoming bookings', 'People who still have a game to play'),
          ('all', 'Everyone who has booked', 'All your past and upcoming customers'),
        ];

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this message?'),
        content: Text('"${_title.text.trim()}" will appear in their notifications. It can\'t be taken back.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ApiClient.post(widget.asAdmin ? '/admin/announcements/' : '/owner/announcements/', {
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'audience': _audience,
        if (!widget.asAdmin && _groundId != null) 'ground': int.parse(_groundId!),
      }) as Map<String, dynamic>;
      final sent = data['sent'] as int;
      messenger.showSnackBar(SnackBar(
        content: Text(sent == 0
            ? 'Nobody to send to yet — no one matches that choice.'
            : 'Sent to $sent ${sent == 1 ? 'person' : 'people'}. ✓'),
      ));
      if (mounted && sent > 0) Navigator.pop(context);
      if (mounted) setState(() => _isSending = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.asAdmin ? 'Send a notice' : 'Message your customers', style: AppTextStyles.subheading),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Who should get it?', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            if (!widget.asAdmin && _grounds.length > 1) ...[
              DropdownButtonFormField<String?>(
                initialValue: _groundId,
                decoration: const InputDecoration(labelText: 'Ground', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All my grounds')),
                  for (final ground in _grounds) DropdownMenuItem(value: ground.id, child: Text(ground.name)),
                ],
                onChanged: (groundId) => setState(() => _groundId = groundId),
              ),
              const SizedBox(height: 8),
            ],
            RadioGroup<String>(
              groupValue: _audience,
              onChanged: (value) => setState(() => _audience = value ?? _audience),
              child: Column(
                children: [
                  for (final (value, label, hint) in _audiences)
                    RadioListTile<String>(
                      value: value,
                      contentPadding: EdgeInsets.zero,
                      title: Text(label, style: AppTextStyles.body),
                      subtitle: Text(hint, style: AppTextStyles.caption),
                      activeColor: AppColors.primaryGreen,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Free drinking water this week',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _message,
              maxLength: 1000,
              maxLines: 6,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Send', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
