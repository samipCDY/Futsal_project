import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../../customer/screens/customer_home_screen.dart';
import '../../owner/screens/owner_home_screen.dart';
import '../../admin/screens/admin_home_screen.dart';

/// Watches [AuthProvider] and swaps in the right module's root screen.
/// This is the single place that decides "customer app" vs "owner app"
/// vs "admin app" — role modules never need to know about each other.
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const SplashScreen();
    }

    switch (auth.currentRole) {
      case UserRole.customer:
        return const CustomerHomeScreen();
      case UserRole.groundOwner:
        return const OwnerHomeScreen();
      case UserRole.admin:
        return const AdminHomeScreen();
      case null:
        return const LoginScreen();
    }
  }
}
