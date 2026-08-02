import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/mock/mock_grounds.dart';
import '../../core/models/map_pin_model.dart';
import 'ground_search_bar.dart';
import 'map_placeholder_canvas.dart';
import 'map_ground_pin.dart';
import 'map_ground_preview_card.dart';
import 'map_controls.dart';

const _myLocation = Offset(0.5, 0.64);

// One pin per known ground — there is no generic points-of-interest layer,
// so nothing except real futsal grounds ever gets a marker here.
const _pins = [
  MapPinModel(groundId: 'g1', position: Offset(0.62, 0.4), showPriceTag: true),
  MapPinModel(groundId: 'g2', position: Offset(0.28, 0.26), showPriceTag: true),
];

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  String _selectedGroundId = 'g1';

  @override
  Widget build(BuildContext context) {
    final selectedPin = _pins.firstWhere((p) => p.groundId == _selectedGroundId);
    final selectedGround = mockGrounds.firstWhere((g) => g.id == _selectedGroundId);

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                MapPlaceholderCanvas(routeStart: _myLocation, routeEnd: selectedPin.position),
                for (final pin in _pins)
                  Positioned(
                    left: pin.position.dx * size.width - (pin.groundId == _selectedGroundId ? 20 : 16),
                    top: pin.position.dy * size.height - (pin.groundId == _selectedGroundId ? 46 : 32),
                    child: MapGroundPin(
                      priceLabel: pin.showPriceTag
                          ? 'Rs ${mockGrounds.firstWhere((g) => g.id == pin.groundId).pricePerHour.toStringAsFixed(0)}/hr'
                          : null,
                      isSelected: pin.groundId == _selectedGroundId,
                      onTap: () => setState(() => _selectedGroundId = pin.groundId),
                    ),
                  ),
                Positioned(
                  left: _myLocation.dx * size.width - 11,
                  top: _myLocation.dy * size.height - 11,
                  child: const MyLocationDot(),
                ),
                Positioned(
                  left: size.width * 0.08,
                  top: size.height * 0.5,
                  child: const _RouteChip(icon: Icons.alt_route, label: 'Fastest · 4 min'),
                ),
                Positioned(
                  right: size.width * 0.1,
                  top: size.height * 0.58,
                  child: const _RouteChip(icon: Icons.straighten, label: 'Shortest · 0.8 km'),
                ),
              ],
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GroundSearchBar(hintText: 'Search this area...', onFilterTap: () {}),
            ),
          ),
        ),
        const Positioned(
          left: 16,
          top: 120,
          child: Column(
            children: [
              MapZoomControls(),
              SizedBox(height: 20),
              MapControlButton(icon: Icons.layers_outlined),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MapControlButton(icon: Icons.my_location, onTap: () {}),
                  const SizedBox(height: 12),
                  MapGroundPreviewCard(
                    ground: selectedGround,
                    onBookNow: () {},
                    onStartRoute: () {},
                    onOpenMap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
