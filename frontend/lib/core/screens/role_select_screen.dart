import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';

/// Dev-only role preview, reached from a link on the real LoginScreen.
/// Lets you jump into any of the three role modules until the backend
/// actually determines role from login credentials.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    void selectRole(UserRole role) {
      auth.signInAs(role);
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Futsal Finder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dev preview — pick a role',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _RoleButton(
                label: 'Continue as Customer',
                onPressed: () => selectRole(UserRole.customer),
              ),
              const SizedBox(height: 16),
              _RoleButton(
                label: 'Continue as Ground Owner',
                onPressed: () => selectRole(UserRole.groundOwner),
              ),
              const SizedBox(height: 16),
              _RoleButton(
                label: 'Continue as Admin',
                onPressed: () => selectRole(UserRole.admin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _RoleButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}
