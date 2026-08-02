import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/logout_confirmation.dart';

/// Placeholder landing screen for the ground owner module.
/// Real dashboard (manage grounds, view bookings, earnings) comes later.
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context),
          ),
        ],
      ),
      body: const Center(
        child: Text('Ground owner dashboard — coming soon'),
      ),
    );
  }
}
