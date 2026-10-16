import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/event_model.dart';
import '../../core/models/ground_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/owner_api.dart';
import '../../core/services/photo_storage.dart';
import '../../core/utils/time_format.dart';

/// Post a new event (no [event]) or edit one.
class EventFormScreen extends StatefulWidget {
  final EventModel? event;

  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  List<GroundModel>? _grounds; // approved grounds the event can be at
  String? _groundId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  late String _posterUrl;
  XFile? _newPoster;
  late bool _publish;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _phone = TextEditingController(
        text: event?.contactPhone ?? context.read<ProfileProvider>().profile?.mobileNumber ?? '');
    _groundId = event?.groundId;
    _startsAt = event?.startsAt;
    _endsAt = event?.endsAt;
    _posterUrl = event?.imageUrl ?? '';
    _publish = event?.isPublished ?? true;
    _loadGrounds();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadGrounds() async {
    try {
      final grounds = (await OwnerApi.fetchMyGrounds()).where((g) => g.status == GroundStatus.approved).toList();
      if (!mounted) return;
      setState(() {
        _grounds = grounds;
        _groundId ??= grounds.length == 1 ? grounds.first.id : null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? current, {DateTime? notBefore}) async {
    final now = DateTime.now();
    final start = notBefore ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(start) ? current : start,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime(now.year, now.month, now.day, 16)),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startsAt);
    if (picked != null) setState(() => _startsAt = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endsAt ?? _startsAt?.add(const Duration(hours: 3)), notBefore: _startsAt);
    if (picked != null) setState(() => _endsAt = picked);
  }

  Future<void> _pickPoster() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (photo != null) setState(() => _newPoster = photo);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open the gallery. Please allow access in your phone's settings."),
      ));
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    String? problem;
    if (_groundId == null) {
      problem = 'Pick the ground the event is at.';
    } else if (_startsAt == null) {
      problem = 'Pick the date and time it starts.';
    } else if (_endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      problem = 'The end must be after the start.';
    }
    if (!formOk || problem != null) {
      if (problem != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = context.read<ProfileProvider>().profile!.id;
    final oldPoster = widget.event?.imageUrl ?? '';
    String? uploaded;
    try {
      if (_newPoster != null) uploaded = await PhotoStorage.groundPhotos.upload(ownerId, _newPoster!);
      final poster = uploaded ?? _posterUrl;
      final startChanged = widget.event?.startsAt != _startsAt;
      await OwnerApi.saveEvent({
        'ground': int.parse(_groundId!),
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'contact_phone': _phone.text.trim(),
        // An unchanged start may already be in the past; the API only checks new ones.
        if (startChanged) 'starts_at': _startsAt!.toUtc().toIso8601String(),
        'ends_at': _endsAt?.toUtc().toIso8601String(),
        'image_url': poster,
        'is_published': _publish,
      }, eventId: widget.event?.id);
      if (oldPoster.isNotEmpty && oldPoster != poster) PhotoStorage.groundPhotos.delete(oldPoster);
      messenger.showSnackBar(SnackBar(
        content: Text(_publish ? 'Event published! Everyone can see it now.' : 'Saved as a draft. Only you can see it.'),
      ));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (uploaded != null) PhotoStorage.groundPhotos.delete(uploaded);
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grounds = _grounds;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_isEditing ? 'Edit event' : 'Post an event', style: AppTextStyles.subheading),
      ),
      body: grounds == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: AppTextStyles.body),
                        TextButton(onPressed: _loadGrounds, child: const Text('Try again')),
                      ],
                    ),
            )
          : grounds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'You need an approved ground before you can post events.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _form(grounds),
    );
  }

  Widget _form(List<GroundModel> grounds) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PosterPicker(newPoster: _newPoster, posterUrl: _posterUrl, onTap: _pickPoster,
              onRemove: () => setState(() {
                    _newPoster = null;
                    _posterUrl = '';
                  })),
          const SizedBox(height: 20),
          TextFormField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Event name',
              hintText: 'e.g. Dashain Futsal Cup',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: grounds.any((g) => g.id == _groundId) ? _groundId : null,
            decoration: const InputDecoration(labelText: 'Ground', border: OutlineInputBorder()),
            items: [for (final ground in grounds) DropdownMenuItem(value: ground.id, child: Text(ground.name))],
            onChanged: (groundId) => setState(() => _groundId = groundId),
          ),
          const SizedBox(height: 16),
          _DateTile(
            label: 'Starts',
            value: _startsAt == null ? 'Tap to pick date and time' : formatDateTime(_startsAt!),
            highlight: _startsAt == null,
            onTap: _pickStart,
          ),
          const SizedBox(height: 12),
          _DateTile(
            label: 'Ends (optional)',
            value: _endsAt == null ? 'Tap to add' : formatDateTime(_endsAt!),
            onTap: _pickEnd,
            onClear: _endsAt == null ? null : () => setState(() => _endsAt = null),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLength: 2000,
            maxLines: 6,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'Teams, entry fee, prizes, rules, last day to register...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
            decoration: const InputDecoration(
              labelText: 'Phone number to register',
              helperText: 'Customers tap "Call to register" and this number rings.',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
              return RegExp(r'^\+?\d{7,15}$').hasMatch(digits) ? null : 'Enter a phone number, e.g. 9812345678';
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Publish now', style: AppTextStyles.body),
            subtitle: Text(
              _publish ? 'Everyone can see it.' : 'Saved as a draft; only you can see it.',
              style: AppTextStyles.caption,
            ),
            value: _publish,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (value) => setState(() => _publish = value),
          ),
          Text('It shows as "Expired" once the date has passed.', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_publish ? 'Publish event' : 'Save draft',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({required this.label, required this.value, required this.onTap, this.highlight = false, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: onClear == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: onClear),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.primaryGreen : AppColors.textPrimary,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PosterPicker extends StatelessWidget {
  final XFile? newPoster;
  final String posterUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PosterPicker({required this.newPoster, required this.posterUrl, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasPoster = newPoster != null || posterUrl.isNotEmpty;
    final Widget image = newPoster != null
        ? Image.file(File(newPoster!.path), fit: BoxFit.cover)
        : posterUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover)
            : Container(
                color: AppColors.subtleFill,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 6),
                    Text('Add a poster (optional)', style: AppTextStyles.caption),
                  ],
                ),
              );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(onTap: onTap, child: image),
            if (hasPoster)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filled(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x99000000)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
