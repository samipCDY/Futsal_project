import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_role.dart';
import '../services/auth_api.dart';
import 'otp_verification_screen.dart';

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return 'Customer';
    case UserRole.groundOwner:
      return 'Ground Owner';
    case UserRole.admin:
      return 'Admin';
  }
}

/// Sign up form shared by every account type — the "User type" field is
/// what actually picks customer/ground owner/admin (our [UserRole] enum),
/// same as the rest of the app.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole? _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty ||
        _mobileController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in your name, mobile number, and email')),
      );
      return;
    }
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user type')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions')),
      );
      return;
    }

    _sendOtpAndContinue();
  }

  Future<void> _sendOtpAndContinue() async {
    final email = _emailController.text.trim();
    final role = _selectedRole!;

    final password = _passwordController.text;
    final fullName = _nameController.text.trim();
    final mobileNumber = _mobileController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await AuthApi.sendOtp(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Sign up verification',
            onVerified: (ctx) async {
              await AuthApi.register(
                email: email,
                password: password,
                fullName: fullName,
                mobileNumber: mobileNumber,
                role: role,
              );
              if (!ctx.mounted) return;
              final messenger = ScaffoldMessenger.of(ctx);
              Navigator.of(ctx).popUntil((route) => route.isFirst);
              messenger.showSnackBar(
                const SnackBar(content: Text('Account created! Please log in.')),
              );
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the server. Is the backend running?')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _pickUserType() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('User type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              // Admin isn't self-service — those accounts get provisioned separately.
              for (final role in const [UserRole.customer, UserRole.groundOwner])
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: AppColors.primaryGreen),
                  title: Text(roleLabel(role)),
                  trailing: _selectedRole == role ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                  onTap: () {
                    setState(() => _selectedRole = role);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel('FULL NAME'),
                    _SignupField(
                      controller: _nameController,
                      icon: Icons.person_outline,
                      hintText: 'Enter your full name',
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('USER TYPE'),
                    _UserTypeField(
                      label: _selectedRole == null ? 'Select user type' : roleLabel(_selectedRole!),
                      isPlaceholder: _selectedRole == null,
                      onTap: _pickUserType,
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('MOBILE NUMBER'),
                    _MobileNumberField(controller: _mobileController),
                    const SizedBox(height: 18),
                    const _FieldLabel('EMAIL'),
                    _SignupField(
                      controller: _emailController,
                      icon: Icons.mail_outline,
                      hintText: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('PASSWORD'),
                    _SignupField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      hintText: '',
                      obscureText: _obscurePassword,
                      trailing: _EyeToggle(
                        obscured: _obscurePassword,
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('CONFIRM PASSWORD'),
                    _SignupField(
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      hintText: '',
                      obscureText: _obscureConfirm,
                      trailing: _EyeToggle(
                        obscured: _obscureConfirm,
                        onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TermsCheckbox(
                      value: _agreedToTerms,
                      onChanged: (value) => setState(() => _agreedToTerms = value),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Login',
                            style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const _SecureFooter(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 4),
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SignupField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? trailing;

  const _SignupField({
    required this.controller,
    required this.icon,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onTap;

  const _EyeToggle({required this.obscured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onTap,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textSecondary,
        size: 20,
      ),
    );
  }
}

class _UserTypeField extends StatelessWidget {
  final String label;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _UserTypeField({required this.label, required this.isPlaceholder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPlaceholder ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MobileNumberField extends StatelessWidget {
  final TextEditingController controller;

  const _MobileNumberField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Text('+977', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 10),
          Container(width: 1, height: 24, color: AppColors.divider),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: '98XXXXXXXX',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            activeColor: AppColors.primaryGreen,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                children: [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F0),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterBadge(icon: Icons.verified_user_outlined, label: 'SECURE'),
              SizedBox(width: 32),
              _FooterBadge(icon: Icons.payments_outlined, label: 'LOCAL PAY'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '© ${DateTime.now().year} Management. All rights reserved.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FooterBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
