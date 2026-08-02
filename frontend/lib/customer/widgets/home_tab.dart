import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/mock/mock_grounds.dart';
import 'location_header.dart';
import 'ground_search_bar.dart';
import 'map_preview_card.dart';
import 'ground_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const LocationHeader(
            initials: 'SC',
            locationLabel: 'Baneshwor, Kathmandu',
            hasNotification: true,
          ),
          const SizedBox(height: 16),
          const GroundSearchBar(),
          const SizedBox(height: 16),
          const MapPreviewCard(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grounds near you', style: AppTextStyles.heading),
              Row(
                children: [
                  Text('Sort: Nearest', style: AppTextStyles.body),
                  const SizedBox(width: 4),
                  const Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final ground in mockGrounds) ...[
            GroundCard(ground: ground, onBookNow: () {}),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
