import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/profile_tab.dart';
import '../widgets/home_tab.dart';
import '../widgets/map_tab.dart';
import '../widgets/bookings_tab.dart';
import 'favourites_screen.dart';

/// Root shell for the customer module: hosts the bottom nav and swaps
/// between Home / Map / Bookings / Profile tabs.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tabIndex = 0;

  static const _navItems = [
    NavItem(icon: Icons.home_outlined, label: 'Home'),
    NavItem(icon: Icons.map_outlined, label: 'Map'),
    NavItem(icon: Icons.calendar_today_outlined, label: 'Bookings'),
    NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  static const _bookingsTabIndex = 2;

  late final _tabs = [
    const HomeTab(),
    const MapTab(),
    const BookingsTab(),
    ProfileTab(
      onOpenBookings: () => setState(() => _tabIndex = _bookingsTabIndex),
      onOpenFavourites: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FavouritesScreen())),
    ),
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
