import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/contact_info.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  /// Opens the dialer/email app; if there isn't one, copies the value so the
  /// user can still use it.
  Future<void> _open(BuildContext context, Uri uri, String value) async {
    final opened = await launchUrl(uri).catchError((_) => false);
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $value')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Contact us', style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("We're here to help with bookings, payments, or anything else.", style: AppTextStyles.body),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                if (ContactInfo.phone.isNotEmpty)
                  _ContactTile(
                    icon: Icons.call_outlined,
                    label: 'Call us',
                    value: ContactInfo.phone,
                    onTap: () => _open(context, Uri(scheme: 'tel', path: ContactInfo.phone), ContactInfo.phone),
                  ),
                if (ContactInfo.email.isNotEmpty)
                  _ContactTile(
                    icon: Icons.email_outlined,
                    label: 'Email us',
                    value: ContactInfo.email,
                    onTap: () => _open(
                      context,
                      Uri(scheme: 'mailto', path: ContactInfo.email, query: 'subject=Futsal Finder help'),
                      ContactInfo.email,
                    ),
                  ),
                const _ContactTile(icon: Icons.location_on_outlined, label: 'Office', value: ContactInfo.address),
                const _ContactTile(icon: Icons.schedule, label: 'Support hours', value: ContactInfo.hours),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactTile({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(label, style: AppTextStyles.caption),
      subtitle: Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 15)),
      trailing: onTap == null ? null : Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
