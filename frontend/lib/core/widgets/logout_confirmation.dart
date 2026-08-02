import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Shows a "Log out of your account?" confirmation dialog. Only actually
/// signs out if the user taps "Logout" — used by every role's logout
/// button so nobody gets signed out from an accidental tap.
Future<void> confirmAndSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text('Logout of your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Logout', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    context.read<AuthProvider>().signOut();
  }
}
