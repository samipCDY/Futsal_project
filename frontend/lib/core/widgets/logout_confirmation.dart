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
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Logout', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await context.read<AuthProvider>().signOut();
  }
}
