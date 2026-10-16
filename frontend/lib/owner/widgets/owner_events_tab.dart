import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/event_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/owner_api.dart';
import '../../core/widgets/event_card.dart';
import '../screens/event_form_screen.dart';

/// The owner's events (drafts included) to edit, publish or delete, and
/// everyone's published events to see what other grounds are running.
class OwnerEventsTab extends StatefulWidget {
  const OwnerEventsTab({super.key});

  @override
  State<OwnerEventsTab> createState() => _OwnerEventsTabState();
}

class _OwnerEventsTabState extends State<OwnerEventsTab> {
  bool _showAll = false;
  List<EventModel>? _events;
  String? _error;

  /// Bumped on every load so a slow answer for the other list can't replace
  /// the one now shown.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    OwnerApi.eventsChanged.addListener(_load);
  }

  @override
  void dispose() {
    OwnerApi.eventsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final events = _showAll ? await FutsalApi.fetchEvents() : await OwnerApi.fetchMyEvents();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _events = events;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _switchList(bool showAll) {
    if (showAll == _showAll) return;
    setState(() {
      _showAll = showAll;
      _events = null;
    });
    _load();
  }

  void _openForm([EventModel? event]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(event: event)));
  }

  Future<void> _setPublished(EventModel event, bool publish) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OwnerApi.saveEvent({'is_published': publish}, eventId: event.id);
      messenger.showSnackBar(SnackBar(
        content: Text(publish ? '${event.title} is published.' : '${event.title} is now a draft (hidden).'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${event.title}?'),
        content: const Text("It's removed for everyone. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OwnerApi.deleteEvent(event.id);
      messenger.showSnackBar(const SnackBar(content: Text('Event deleted.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _actions(EventModel event) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => _openForm(event),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit'),
        ),
        if (!event.isExpired)
          TextButton.icon(
            onPressed: () => _setPublished(event, !event.isPublished),
            icon: Icon(event.isPublished ? Icons.visibility_off_outlined : Icons.publish, size: 16),
            label: Text(event.isPublished ? 'Unpublish' : 'Publish'),
          ),
        const Spacer(),
        IconButton(
          onPressed: () => _delete(event),
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline, color: AppColors.dangerText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post event'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Text('Events', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
              const SizedBox(height: 4),
              Text('Tournaments and events at your grounds.', style: AppTextStyles.caption),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('My events'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: true, label: Text('All events'), icon: Icon(Icons.public)),
                ],
                selected: {_showAll},
                onSelectionChanged: (selection) => _switchList(selection.first),
              ),
              const SizedBox(height: 16),
              if (events == null && _error != null)
                Column(
                  children: [
                    Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ],
                )
              else if (events == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    _showAll ? 'No events posted yet.' : 'You haven\'t posted any events.\nTap "Post event" to start.',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final event in events) ...[
                  EventCard(event: event, actions: event.isMine ? _actions(event) : null),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
