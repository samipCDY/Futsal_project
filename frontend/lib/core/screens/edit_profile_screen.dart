import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/profile_provider.dart';
import '../services/api_exception.dart';
import '../utils/time_format.dart';
import '../utils/validators.dart';

const _genders = {'male': 'Male', 'female': 'Female', 'other': 'Other'};

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _dateOfBirthText;
  DateTime? _dateOfBirth;
  String? _gender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _firstName = TextEditingController(text: profile?.firstName ?? '');
    _lastName = TextEditingController(text: profile?.lastName ?? '');
    _mobile = TextEditingController(text: profile?.mobileNumber ?? '');
    _address = TextEditingController(text: profile?.address ?? '');
    _city = TextEditingController(text: profile?.city ?? '');
    _dateOfBirth = profile?.dateOfBirth;
    _dateOfBirthText = TextEditingController(text: _dateOfBirth == null ? '' : formatDateDayMonthYear(_dateOfBirth!));
    _gender = profile?.gender;
  }

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _mobile, _address, _city, _dateOfBirthText]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now.subtract(const Duration(days: 1)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dateOfBirthText.text = formatDateDayMonthYear(picked);
    });
  }

  void _clearDateOfBirth() {
    setState(() {
      _dateOfBirth = null;
      _dateOfBirthText.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ProfileProvider>().updateDetails({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'date_of_birth': _dateOfBirth == null ? null : formatDateApi(_dateOfBirth!),
        'gender': _gender ?? '',
        'mobile_number': _mobile.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  InputDecoration _decoration(String label, {String? hint, Widget? suffixIcon, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final email = context.watch<ProfileProvider>().profile?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Edit profile', style: AppTextStyles.subheading),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('Personal details'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('First name'),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateOfBirthText,
              readOnly: true,
              onTap: _pickDateOfBirth,
              decoration: _decoration(
                'Date of birth',
                hint: 'Tap to choose',
                suffixIcon: _dateOfBirth == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(icon: const Icon(Icons.close), tooltip: 'Clear', onPressed: _clearDateOfBirth),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _gender,
              decoration: _decoration('Gender'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Prefer not to say')),
                for (final entry in _genders.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Contact'),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('Mobile number', hint: '98XXXXXXXX').copyWith(prefixText: '+977  '),
              validator: (value) => mobileError(value ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: _decoration('Email', helper: "Email is your login, so it can't be changed here."),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Address'),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Street / Tole', hint: 'e.g. Naya Baneshwor, Ward 10'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: _decoration('City', hint: 'e.g. Kathmandu'),
            ),
            const SizedBox(height: 28),
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
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppTextStyles.subheading),
    );
  }
}
