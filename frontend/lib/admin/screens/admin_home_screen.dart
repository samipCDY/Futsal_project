import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/logout_confirmation.dart';

/// Placeholder landing screen for the main admin module.
/// Real dashboard (manage users, grounds, disputes) comes later.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context),
          ),
        ],
      ),
      body: const Center(
        child: Text('Admin dashboard — coming soon'),
      ),
    );
  }
}
