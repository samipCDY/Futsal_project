import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/owner_api.dart';
import '../../core/services/photo_storage.dart';
import '../../core/utils/time_format.dart';
import 'location_picker_screen.dart';

/// Add a new ground (no [ground]) or edit an existing one.
class GroundFormScreen extends StatefulWidget {
  final GroundModel? ground;

  const GroundFormScreen({super.key, this.ground});

  @override
  State<GroundFormScreen> createState() => _GroundFormScreenState();
}

class _GroundFormScreenState extends State<GroundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final TextEditingController _morningPrice;
  late final TextEditingController _dayPrice;
  late final TextEditingController _eveningPrice;
  late final TextEditingController _badge;
  late int _opensAt; // hour, 0-23
  late int _closesAt;
  LatLng? _location;
  late String _photoUrl; // saved photo, "" if none
  XFile? _newPhoto; // picked but not uploaded yet
  late final String _documentPath; // saved lalpurja photo, "" if none
  XFile? _newDocument;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEditing => widget.ground != null;

  @override
  void initState() {
    super.initState();
    final ground = widget.ground;
    _name = TextEditingController(text: ground?.name ?? '');
    _area = TextEditingController(text: ground?.area ?? '');
    _address = TextEditingController(text: ground?.address ?? '');
    String price(double? value) => value == null ? '' : value.toStringAsFixed(0);
    _morningPrice = TextEditingController(text: price(ground?.morningPrice));
    _dayPrice = TextEditingController(text: price(ground?.dayPrice));
    _eveningPrice = TextEditingController(text: price(ground?.eveningPrice));
    _badge = TextEditingController(text: ground?.badgeLabel ?? '');
    _opensAt = int.parse((ground?.opensAt ?? '06').split(':').first);
    _closesAt = int.parse((ground?.closesAt ?? '22').split(':').first);
    _location = ground?.location;
    _photoUrl = ground?.imageUrl ?? '';
    _documentPath = ground?.ownershipDocument ?? '';
    _isActive = ground?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [_name, _area, _address, _morningPrice, _dayPrice, _eveningPrice, _badge]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _hourLabel(int hour) => formatClock('$hour:00');

  /// Slots are booked by the hour, so opening and closing are whole hours.
  Future<void> _pickHour({required bool opening}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: opening ? _opensAt : _closesAt, minute: 0),
      helpText: opening ? 'Opens at (whole hours only)' : 'Closes at (whole hours only)',
    );
    if (picked == null) return;
    setState(() => opening ? _opensAt = picked.hour : _closesAt = picked.hour);
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _location)),
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<String?> _askPhotoSource({required bool canRemove}) => showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: AppColors.primaryGreen),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.primaryGreen),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              if (canRemove)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.dangerText),
                  title: Text('Remove photo', style: TextStyle(color: AppColors.dangerText)),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
            ],
          ),
        ),
      );

  /// Opens the camera or gallery; null if cancelled or not allowed.
  Future<XFile?> _takePhoto(String source, {int maxSize = 1280}) async {
    try {
      return await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxSize.toDouble(),
        maxHeight: maxSize.toDouble(),
        imageQuality: 85,
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't open the camera or gallery. Please allow access in your phone's settings."),
        ));
      }
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    final choice = await _askPhotoSource(canRemove: _newPhoto != null || _photoUrl.isNotEmpty);
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      setState(() {
        _newPhoto = null;
        _photoUrl = '';
      });
      return;
    }
    final photo = await _takePhoto(choice);
    if (photo != null) setState(() => _newPhoto = photo);
  }

  /// The lalpurja is required, so it can be replaced but not removed. A
  /// larger size keeps the writing on it readable.
  Future<void> _pickDocument() async {
    final choice = await _askPhotoSource(canRemove: false);
    if (choice == null || !mounted) return;
    final photo = await _takePhoto(choice, maxSize: 2000);
    if (photo != null) setState(() => _newDocument = photo);
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    String? problem;
    if (_location == null) {
      problem = 'Please pick the ground\'s location on the map.';
    } else if (_closesAt <= _opensAt) {
      problem = 'Closing time must be after opening time.';
    } else if (_newDocument == null && _documentPath.isEmpty) {
      problem = 'Please add a photo of the lalpurja (land ownership paper).';
    }
    if (!formOk || problem != null) {
      if (problem != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = context.read<ProfileProvider>().profile!.id;
    final oldPhotoUrl = widget.ground?.imageUrl ?? '';
    String? uploadedUrl;
    String? uploadedDocument;
    try {
      if (_newPhoto != null) uploadedUrl = await PhotoStorage.groundPhotos.upload(ownerId, _newPhoto!);
      if (_newDocument != null) {
        uploadedDocument = await PhotoStorage.groundDocuments.upload(ownerId, _newDocument!);
      }
      final photoUrl = uploadedUrl ?? _photoUrl;
      final documentPath = uploadedDocument ?? _documentPath;
      final saved = await OwnerApi.saveGround({
        'name': _name.text.trim(),
        'area': _area.text.trim(),
        'address': _address.text.trim(),
        'morning_price': _morningPrice.text.trim(),
        'day_price': _dayPrice.text.trim(),
        'evening_price': _eveningPrice.text.trim(),
        'badge_label': _badge.text.trim(),
        'opens_at': '${_opensAt.toString().padLeft(2, '0')}:00',
        'closes_at': '${_closesAt.toString().padLeft(2, '0')}:00',
        'latitude': _location!.latitude.toStringAsFixed(6),
        'longitude': _location!.longitude.toStringAsFixed(6),
        'image_url': photoUrl,
        'ownership_document': documentPath,
        if (_isEditing) 'is_active': _isActive,
      }, groundId: widget.ground?.id);

      if (oldPhotoUrl.isNotEmpty && oldPhotoUrl != photoUrl) PhotoStorage.groundPhotos.delete(oldPhotoUrl);
      if (_documentPath.isNotEmpty && _documentPath != documentPath) {
        PhotoStorage.groundDocuments.delete(_documentPath);
      }
      final sentForApproval = saved.status == GroundStatus.pending && widget.ground?.status != GroundStatus.pending;
      messenger.showSnackBar(SnackBar(
        content: Text(!_isEditing
            ? 'Ground sent for approval! You\'ll get an email once it\'s approved.'
            : sentForApproval
                ? 'Changes saved and sent for approval.'
                : 'Changes saved.'),
      ));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (uploadedUrl != null) PhotoStorage.groundPhotos.delete(uploadedUrl);
      if (uploadedDocument != null) PhotoStorage.groundDocuments.delete(uploadedDocument);
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  InputDecoration _decoration(String label, {String? hint, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: const OutlineInputBorder(),
      );

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;

  Widget _priceField(TextEditingController controller, String label, String hours) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'Rs ',
          helperText: hours,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        ),
        validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Enter a price' : null,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_isEditing ? 'Edit ground' : 'Add ground', style: AppTextStyles.subheading),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEditing && widget.ground!.status == GroundStatus.rejected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Not approved: ${widget.ground!.reviewNote}\nFix it below and save to send it again.',
                  style: TextStyle(color: AppColors.dangerText),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _PhotoPicker(newPhoto: _newPhoto, photoUrl: _photoUrl, onTap: _pickPhoto),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Ground name', hint: 'e.g. Thunder Futsal Arena'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Area', hint: 'e.g. Koteshwor'),
              validator: _required,
            ),
            const SizedBox(height: 20),
            Text('Price per hour', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text('Set a different rate for each time of day. Evening is usually the peak time.',
                style: AppTextStyles.caption),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _priceField(_morningPrice, '🌅 Morning', 'before ${_hourLabel(dayStartsHour)}')),
                const SizedBox(width: 8),
                Expanded(
                  child: _priceField(
                      _dayPrice, '☀️ Day', '${_hourLabel(dayStartsHour)} – ${_hourLabel(eveningStartsHour)}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _priceField(_eveningPrice, '🌙 Evening', 'peak · from ${_hourLabel(eveningStartsHour)}'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Address (optional)', hint: 'Street, landmark'),
            ),
            const SizedBox(height: 16),
            _PickerTile(
              icon: Icons.location_on_outlined,
              label: 'Location on map',
              value: _location == null ? 'Tap to pick' : 'Location set ✓',
              highlight: _location == null,
              onTap: _pickLocation,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Opens at',
                    value: _hourLabel(_opensAt),
                    onTap: () => _pickHour(opening: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.nightlight_outlined,
                    label: 'Closes at',
                    value: _hourLabel(_closesAt),
                    onTap: () => _pickHour(opening: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _badge,
              maxLength: 60,
              decoration: _decoration('Highlight (optional)', hint: 'e.g. Free bibs + water'),
            ),
            const SizedBox(height: 8),
            Text('Lalpurja (land ownership paper)', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'A clear photo of the lalpurja or rent agreement for this land. Only our team sees it, to check '
              'the ground is really yours. Customers see the ground after it is approved.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            _DocumentPicker(newDocument: _newDocument, documentPath: _documentPath, onTap: _pickDocument),
            if (_isEditing && widget.ground!.status == GroundStatus.approved) ...[
              const SizedBox(height: 12),
              Text(
                'Changing the name, area, address, location or lalpurja sends the ground for approval again, '
                'and it is hidden from customers until approved. Prices and hours can be changed any time.',
                style: AppTextStyles.caption.copyWith(color: AppColors.statusPendingText),
              ),
            ],
            const SizedBox(height: 8),
            if (_isEditing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Show to customers', style: AppTextStyles.body),
                subtitle: Text(
                  _isActive ? 'Customers can find and book this ground.' : 'Hidden — no new bookings.',
                  style: AppTextStyles.caption,
                ),
                value: _isActive,
                activeThumbColor: AppColors.primaryGreen,
                onChanged: (value) => setState(() => _isActive = value),
              ),
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
                  : Text(_isEditing ? 'Save changes' : 'Add ground',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? newPhoto;
  final String photoUrl;
  final VoidCallback onTap;

  const _PhotoPicker({required this.newPhoto, required this.photoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (newPhoto != null) {
      image = Image.file(File(newPhoto!.path), fit: BoxFit.cover);
    } else if (photoUrl.isNotEmpty) {
      image = CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover);
    } else {
      image = Container(
        color: AppColors.subtleFill,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text('Add a photo of your ground', style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 170,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (newPhoto != null || photoUrl.isNotEmpty)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Change photo', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lalpurja photo: the one just picked, or the saved one through a
/// short-lived link (the bucket is private).
class _DocumentPicker extends StatefulWidget {
  final XFile? newDocument;
  final String documentPath;
  final VoidCallback onTap;

  const _DocumentPicker({required this.newDocument, required this.documentPath, required this.onTap});

  @override
  State<_DocumentPicker> createState() => _DocumentPickerState();
}

class _DocumentPickerState extends State<_DocumentPicker> {
  Future<String?>? _savedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.documentPath.isNotEmpty) _savedUrl = PhotoStorage.groundDocuments.signedUrl(widget.documentPath);
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = widget.newDocument != null || widget.documentPath.isNotEmpty;
    final Widget content;
    if (widget.newDocument != null) {
      content = Image.file(File(widget.newDocument!.path), fit: BoxFit.cover);
    } else if (_savedUrl != null) {
      content = FutureBuilder<String?>(
        future: _savedUrl,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) {
            return Center(
              child: snapshot.connectionState == ConnectionState.done
                  ? Text('Lalpurja uploaded ✓', style: AppTextStyles.body)
                  : const CircularProgressIndicator(),
            );
          }
          return Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text('Lalpurja uploaded ✓', style: AppTextStyles.body)));
        },
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 36, color: AppColors.primaryGreen),
          const SizedBox(height: 6),
          Text('Add lalpurja photo', style: AppTextStyles.body.copyWith(color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600)),
          Text('Required', style: AppTextStyles.caption),
        ],
      );
    }
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.subtleFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasDocument ? AppColors.divider : AppColors.primaryGreen),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (hasDocument)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
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
