import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/profile_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/api_exception.dart';
import '../../core/widgets/logout_confirmation.dart';
import '../../core/widgets/profile_avatar.dart';
import '../screens/contact_us_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/favourites_screen.dart';

const _languageNames = {'en': 'English', 'ne': 'नेपाली'};
const _themeNames = {'system': 'System', 'light': 'Light', 'dark': 'Dark'};

class ProfileTab extends StatelessWidget {
  /// Switches the home screen to the Bookings tab.
  final VoidCallback? onOpenBookings;

  const ProfileTab({super.key, this.onOpenBookings});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// Saves a preference; on failure the provider puts the old value back
  /// and we say why.
  Future<void> _savePreference(BuildContext context, Preferences Function(Preferences) change) async {
    try {
      await context.read<ProfileProvider>().updatePreferences(change);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return SafeArea(
        child: Center(
          child: profileProvider.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(profileProvider.error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                    TextButton(onPressed: profileProvider.load, child: const Text('Try again')),
                  ],
                ),
        ),
      );
    }
    final preferences = profile.preferences;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _GreetingBubbleAvatar(
            greeting: _greeting,
            initials: profile.initials,
            photoUrl: profile.avatarUrl,
            isSaving: profileProvider.isSavingPhoto,
            onTap: () => _showPhotoOptions(context, hasPhoto: profile.avatarUrl.isNotEmpty),
          ),
          const SizedBox(height: 14),
          Text(profile.fullName, textAlign: TextAlign.center, style: AppTextStyles.subheading.copyWith(fontSize: 18)),
          if (profile.email.isNotEmpty)
            Text(profile.email, textAlign: TextAlign.center, style: AppTextStyles.caption),
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
                  onTap: () => _push(context, const EditProfileScreen()),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.event_available_outlined,
                  label: 'My bookings',
                  onTap: onOpenBookings,
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.favorite_border,
                  label: 'Favourite grounds',
                  onTap: () => _push(context, const FavouritesScreen()),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.palette_outlined,
                  label: 'Appearance',
                  trailingText: _themeNames[preferences.theme],
                  onTap: () => _showChoices(
                    context,
                    title: 'Appearance',
                    options: const [
                      ('system', 'System (same as phone)', Icons.brightness_auto_outlined),
                      ('light', 'Light', Icons.light_mode_outlined),
                      ('dark', 'Dark', Icons.dark_mode_outlined),
                    ],
                    selected: preferences.theme,
                    onSelected: (theme) => _savePreference(context, (p) => p.copyWith(theme: theme)),
                  ),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.language,
                  label: 'Language',
                  trailingText: _languageNames[preferences.language],
                  onTap: () => _showChoices(
                    context,
                    title: 'Language',
                    options: const [
                      ('en', 'English', Icons.translate),
                      ('ne', 'नेपाली', Icons.translate),
                    ],
                    selected: preferences.language,
                    onSelected: (language) => _savePreference(context, (p) => p.copyWith(language: language)),
                  ),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  trailing: Switch(
                    value: preferences.notificationsEnabled,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (enabled) =>
                        _savePreference(context, (p) => p.copyWith(notificationsEnabled: enabled)),
                  ),
                ),
                const _TileDivider(),
                _ProfileTile(
                  icon: Icons.support_agent_outlined,
                  label: 'Contact us',
                  onTap: () => _push(context, const ContactUsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => confirmAndSignOut(context),
              icon: Icon(Icons.logout, size: 22, color: AppColors.textSecondary),
              label: Text(
                'Log out',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhotoOptions(BuildContext context, {required bool hasPhoto}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.primaryGreen),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primaryGreen),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.dangerText),
                title: Text('Remove photo', style: TextStyle(color: AppColors.dangerText)),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final profileProvider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'remove') {
        await profileProvider.removePhoto();
        messenger.showSnackBar(const SnackBar(content: Text('Photo removed.')));
        return;
      }
      // Small and compressed: plenty for a profile circle, quick to upload.
      final photo = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (photo == null) return; // user backed out
      await profileProvider.changePhoto(photo);
      messenger.showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on PlatformException {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't open the camera or gallery. Please allow access in your phone's settings."),
      ));
    }
  }

  /// Bottom sheet listing [options] as (value, label, icon).
  void _showChoices(
    BuildContext context, {
    required String title,
    required List<(String, String, IconData)> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              for (final (value, label, icon) in options)
                _AppearanceOption(
                  label: label,
                  icon: icon,
                  selected: value == selected,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (value != selected) onSelected(value);
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
  final String photoUrl;
  final bool isSaving;
  final VoidCallback? onTap;

  const _AvatarWithEditBadge({required this.initials, required this.photoUrl, required this.isSaving, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: isSaving ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(photoUrl: photoUrl, initials: initials, size: 96),
            if (isSaving)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
                child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingBubbleAvatar extends StatelessWidget {
  final String greeting;
  final String initials;
  final String photoUrl;
  final bool isSaving;
  final VoidCallback? onTap;

  const _GreetingBubbleAvatar({
    required this.greeting,
    required this.initials,
    required this.photoUrl,
    required this.isSaving,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GreetingBubble(text: greeting),
        Transform.translate(
          offset: const Offset(0, -6),
          child: _AvatarWithEditBadge(initials: initials, photoUrl: photoUrl, isSaving: isSaving, onTap: onTap),
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
              Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
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
    return Divider(height: 1, color: AppColors.divider);
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
      trailing: selected ? Icon(Icons.check, color: AppColors.primaryGreen) : null,
      onTap: onTap,
    );
  }
}
