import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../widgets/ground_card.dart';
import 'ground_booking_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<GroundModel>? _grounds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final grounds = await FutsalApi.fetchFavourites();
      if (!mounted) return;
      setState(() {
        _grounds = grounds;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _remove(GroundModel ground) async {
    setState(() => _grounds!.removeWhere((g) => g.id == ground.id));
    try {
      await FutsalApi.setFavourite(ground.id, false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  void _openBooking(GroundModel ground) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroundBookingScreen(ground: ground)));
  }

  @override
  Widget build(BuildContext context) {
    final grounds = _grounds;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Favourite grounds', style: AppTextStyles.subheading),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null && grounds == null)
              Column(
                children: [
                  Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else if (grounds == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (grounds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No favourites yet. Tap the ♥ on a ground to save it here.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final ground in grounds) ...[
                GroundCard(
                  ground: ground,
                  onTap: () => _openBooking(ground),
                  onBookNow: () => _openBooking(ground),
                  onFavouriteTap: () => _remove(ground),
                ),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}
