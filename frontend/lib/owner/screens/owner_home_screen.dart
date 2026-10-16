import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/profile_tab.dart';
import '../widgets/owner_bookings_tab.dart';
import '../widgets/owner_dashboard_tab.dart';
import '../widgets/owner_events_tab.dart';
import '../widgets/owner_grounds_tab.dart';

/// Root shell for the ground owner module: Dashboard / Grounds / Bookings /
/// Events / Profile tabs.
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _tabIndex = 0;

  static const _navItems = [
    NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    NavItem(icon: Icons.sports_soccer_outlined, label: 'Grounds'),
    NavItem(icon: Icons.calendar_today_outlined, label: 'Bookings'),
    NavItem(icon: Icons.emoji_events_outlined, label: 'Events'),
    NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  static const _bookingsTabIndex = 2;

  void _openBookings() => setState(() => _tabIndex = _bookingsTabIndex);

  late final _tabs = [
    OwnerDashboardTab(onOpenBookings: _openBookings),
    const OwnerGroundsTab(),
    const OwnerBookingsTab(),
    const OwnerEventsTab(),
    ProfileTab(onOpenBookings: _openBookings),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: AppBottomNavBar(
        items: _navItems,
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}
