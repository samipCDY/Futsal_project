import 'package:flutter/material.dart';
import '../config/contact_info.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

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
                    onTap: () => callNumber(context, ContactInfo.phone),
                  ),
                if (ContactInfo.email.isNotEmpty)
                  _ContactTile(
                    icon: Icons.email_outlined,
                    label: 'Email us',
                    value: ContactInfo.email,
                    onTap: () => openOrCopy(
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
