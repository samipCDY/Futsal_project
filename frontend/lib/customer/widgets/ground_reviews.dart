import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/review_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/utils/time_format.dart';

/// Five stars filled to [rating], e.g. 4.5 shows four and a half.
class StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: AppColors.rating,
          ),
      ],
    );
  }
}

/// "4.5 ★★★★½ (23)", or "No reviews yet".
class RatingLine extends StatelessWidget {
  final double? rating;
  final int count;

  const RatingLine({super.key, required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null || count == 0) return Text('No reviews yet', style: AppTextStyles.caption);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.toStringAsFixed(1), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        StarRow(rating: value),
        const SizedBox(width: 4),
        Text('($count)', style: AppTextStyles.caption),
      ],
    );
  }
}

/// A ground's reviews: the average, how many gave each star, a button to
/// write (or edit) your own after playing there, and the reviews.
class GroundReviewsSection extends StatefulWidget {
  final String groundId;
  final String groundName;

  const GroundReviewsSection({super.key, required this.groundId, required this.groundName});

  @override
  State<GroundReviewsSection> createState() => _GroundReviewsSectionState();
}

class _GroundReviewsSectionState extends State<GroundReviewsSection> {
  GroundReviews? _reviews;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    FutsalApi.reviewsChanged.addListener(_load);
  }

  @override
  void didUpdateWidget(GroundReviewsSection old) {
    super.didUpdateWidget(old);
    if (old.groundId != widget.groundId) {
      setState(() => _reviews = null);
      _load();
    }
  }

  @override
  void dispose() {
    FutsalApi.reviewsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final groundId = widget.groundId;
    try {
      final reviews = await FutsalApi.fetchReviews(groundId);
      if (!mounted || groundId != widget.groundId) return;
      setState(() {
        _reviews = reviews;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    if (reviews == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : TextButton(onPressed: _load, child: Text("$_error\nTry again", textAlign: TextAlign.center)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: AppTextStyles.subheading),
        const SizedBox(height: 12),
        if (reviews.reviewCount > 0) ...[
          _Summary(reviews: reviews),
          const SizedBox(height: 12),
        ],
        if (reviews.canReview)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showWriteReviewSheet(context,
                  groundId: widget.groundId, groundName: widget.groundName, existing: reviews.myReview),
              icon: Icon(reviews.myReview == null ? Icons.rate_review_outlined : Icons.edit_outlined, size: 18),
              label: Text(reviews.myReview == null ? 'Write a review' : 'Edit your review'),
            ),
          )
        else
          Text('Play here once and you can rate this ground.', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        if (reviews.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No reviews yet. Be the first after your game!', style: AppTextStyles.body),
          )
        else
          for (final review in reviews.reviews) _ReviewTile(review: review),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final GroundReviews reviews;

  const _Summary({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final most = reviews.stars.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              for (var stars = 5; stars >= 1; stars--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 12, child: Text('$stars', style: AppTextStyles.caption)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: most == 0 ? 0 : (reviews.stars[stars] ?? 0) / most,
                            minHeight: 8,
                            backgroundColor: AppColors.subtleFill,
                            color: AppColors.rating,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          children: [
            Text(reviews.rating!.toStringAsFixed(1),
                style: AppTextStyles.heading.copyWith(fontSize: 34, fontWeight: FontWeight.w800)),
            StarRow(rating: reviews.rating!),
            const SizedBox(height: 2),
            Text('${reviews.reviewCount} review${reviews.reviewCount == 1 ? '' : 's'}', style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.subtleFill,
                foregroundImage: review.customerPhoto.isEmpty ? null : NetworkImage(review.customerPhoto),
                child: Text(review.initials, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(review.customerName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              StarRow(rating: review.rating.toDouble(), size: 13),
              const SizedBox(width: 8),
              Text(formatAgo(review.updatedAt), style: AppTextStyles.caption),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }
}

/// Lets the customer pick 1-5 stars and write a comment. Editing shows a
/// Delete button too.
Future<void> showWriteReviewSheet(
  BuildContext context, {
  required String groundId,
  required String groundName,
  ReviewModel? existing,
  int? stars,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _WriteReviewSheet(groundId: groundId, groundName: groundName, existing: existing, stars: stars),
  );
}

class _WriteReviewSheet extends StatefulWidget {
  final String groundId;
  final String groundName;
  final ReviewModel? existing;

  /// Stars already tapped, e.g. on a played booking.
  final int? stars;

  const _WriteReviewSheet({required this.groundId, required this.groundName, this.existing, this.stars});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  late int _rating = widget.stars ?? widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');
  bool _saving = false;

  static const _labels = ['', 'Poor', 'Not good', 'Okay', 'Good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate ${widget.groundName}', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text('Your name and review are shown to everyone.', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var stars = 1; stars <= 5; stars++)
                IconButton(
                  tooltip: '$stars star${stars == 1 ? '' : 's'}',
                  onPressed: _saving ? null : () => setState(() => _rating = stars),
                  icon: Icon(
                    stars <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: AppColors.rating,
                  ),
                ),
            ],
          ),
          Center(child: Text(_labels[_rating], style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            enabled: !_saving,
            decoration: const InputDecoration(
              hintText: 'How was the turf, lights, changing rooms, staff...?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _run(() => FutsalApi.deleteReview(widget.groundId), 'Your review was removed.'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
                  child: const Text('Delete'),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving || _rating == 0
                    ? null
                    : () => _run(
                          () => FutsalApi.saveReview(widget.groundId, rating: _rating, comment: _comment.text.trim()),
                          'Thanks for your review!',
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text(_saving ? 'Saving...' : 'Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
