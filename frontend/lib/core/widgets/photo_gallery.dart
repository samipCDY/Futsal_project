import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Swipeable photos with dots and a "2 / 5" count. Tapping one opens them
/// full screen, where they can be zoomed.
class PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final double height;
  final BorderRadius borderRadius;

  const PhotoCarousel({
    super.key,
    required this.photos,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: photos.isEmpty
            ? const GroundPhotoPlaceholder()
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => openPhotoViewer(context, photos, index),
                      child: CachedNetworkImage(
                        imageUrl: photos[index],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: AppColors.subtleFill),
                        errorWidget: (_, __, ___) => const GroundPhotoPlaceholder(),
                      ),
                    ),
                  ),
                  if (photos.length > 1) ...[
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _Chip(text: '${_page + 1} / ${photos.length}'),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _page ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: i == _page ? 1 : 0.6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Green card with a ball, for a ground without photos.
class GroundPhotoPlaceholder extends StatelessWidget {
  const GroundPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen.withValues(alpha: 0.85), AppColors.darkGreen],
        ),
      ),
      child: const Center(child: Icon(Icons.sports_soccer, size: 56, color: Colors.white24)),
    );
  }
}

/// [photos] full screen on black, starting at [index]. Pinch to zoom,
/// swipe for the next one.
Future<void> openPhotoViewer(BuildContext context, List<String> photos, int index) {
  return Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PhotoViewer(photos: photos, initial: index)),
  );
}

class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initial;

  const _PhotoViewer({required this.photos, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_page + 1} / ${widget.photos.length}', style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.photos[index],
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
