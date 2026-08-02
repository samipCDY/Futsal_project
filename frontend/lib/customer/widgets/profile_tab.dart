import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/logout_confirmation.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _GreetingBubbleAvatar(greeting: _greeting, initials: 'SC'),
          const SizedBox(height: 14),
          Text('Samip Chaudhary', textAlign: TextAlign.center, style: AppTextStyles.subheading.copyWith(fontSize: 18)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.person_outline,
                  label: 'Edit profile',
                  onTap: () {},
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.event_available_outlined,
                  label: 'My bookings',
                  onTap: () {},
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.favorite_border,
                  label: 'Favourite grounds',
                  onTap: () {},
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.palette_outlined,
                  label: 'Appearance',
                  trailingText: themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                  onTap: () => _showAppearancePicker(context),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.language,
                  label: 'Language',
                  trailingText: 'English / नेपाली',
                  onTap: () {},
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  trailing: Switch(
                    value: true,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (_) {},
                  ),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.support_agent_outlined,
                  label: 'Contact us',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => confirmAndSignOut(context),
              icon: const Icon(Icons.logout, size: 22, color: AppColors.textSecondary),
              label: const Text(
                'Log out',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppearancePicker(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              _AppearanceOption(
                label: 'Light',
                icon: Icons.light_mode_outlined,
                selected: themeProvider.mode == ThemeMode.light,
                onTap: () {
                  themeProvider.setMode(ThemeMode.light);
                  Navigator.of(sheetContext).pop();
                },
              ),
              _AppearanceOption(
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
                selected: themeProvider.mode == ThemeMode.dark,
                onTap: () {
                  themeProvider.setMode(ThemeMode.dark);
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
}

class _AvatarWithEditBadge extends StatelessWidget {
  final String initials;

  const _AvatarWithEditBadge({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(Icons.edit, size: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingBubbleAvatar extends StatelessWidget {
  final String greeting;
  final String initials;

  const _GreetingBubbleAvatar({required this.greeting, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GreetingBubble(text: greeting),
        Transform.translate(
          offset: const Offset(0, -6),
          child: _AvatarWithEditBadge(initials: initials),
        ),
      ],
    );
  }
}

class _GreetingBubble extends StatelessWidget {
  final String text;

  const _GreetingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(width: 10, height: 10, color: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    this.trailingText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 15))),
            if (trailingText != null) ...[
              Text(trailingText!, style: AppTextStyles.caption),
              const SizedBox(width: 6),
            ],
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.divider);
  }
}

class _AppearanceOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
      onTap: onTap,
    );
  }
}
