import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/owner_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/date_strip.dart';
import 'owner_booking_tile.dart';

const _daysBack = 7;
const _daysAhead = 30;

/// Everyone booked at the owner's grounds on a chosen day.
class OwnerBookingsTab extends StatefulWidget {
  const OwnerBookingsTab({super.key});

  @override
  State<OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}

class _OwnerBookingsTabState extends State<OwnerBookingsTab> {
  late final DateTime _today;
  late final List<DateTime> _days;
  late DateTime _selectedDay;
  String? _groundId; // null = all grounds
  List<GroundModel> _grounds = [];
  List<BookingModel>? _bookings;
  String? _error;

  /// Bumped on every load so a slow answer for an earlier day/ground can't
  /// replace the bookings for the one now selected.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _days = [for (var i = -_daysBack; i <= _daysAhead; i++) _today.add(Duration(days: i))];
    _selectedDay = _today;
    _load();
    _loadGrounds();
    FutsalApi.bookingsChanged.addListener(_load);
    OwnerApi.groundsChanged.addListener(_loadGrounds);
  }

  @override
  void dispose() {
    FutsalApi.bookingsChanged.removeListener(_load);
    OwnerApi.groundsChanged.removeListener(_loadGrounds);
    super.dispose();
  }

  Future<void> _loadGrounds() async {
    try {
      final grounds = await OwnerApi.fetchMyGrounds();
      if (mounted) setState(() => _grounds = grounds);
    } on ApiException {
      // The ground filter is optional; bookings still load without it.
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final bookings = await OwnerApi.fetchBookings(_selectedDay, groundId: _groundId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _bookings = bookings;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _select({DateTime? day, String? groundId, bool allGrounds = false}) {
    setState(() {
      if (day != null) _selectedDay = day;
      if (groundId != null || allGrounds) _groundId = groundId;
      _bookings = null;
    });
    _load();
  }

  Future<void> _pickAnyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today.add(const Duration(days: 90)),
    );
    if (picked != null) _select(day: picked);
  }

  Future<void> _cancel(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          '${booking.customerName ?? 'The customer'} · ${booking.timeLabel}\n\n'
          'Please let them know — call ${booking.customerPhone ?? 'them'} before cancelling.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FutsalApi.cancelBooking(booking.id); // the listener reloads the list
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = _bookings;
    final live = (bookings ?? []).where((b) => b.status != BookingStatus.cancelled).toList();
    final total = live.fold<double>(0, (sum, b) => sum + b.price);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Bookings', style: AppTextStyles.heading.copyWith(color: AppColors.primaryGreen)),
                ),
                IconButton(
                  onPressed: _pickAnyDate,
                  tooltip: 'Pick a date',
                  icon: Icon(Icons.calendar_month_outlined, color: AppColors.primaryGreen),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DateStrip(days: _days, selected: _selectedDay, onSelected: (day) => _select(day: day)),
          ),
          if (_grounds.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String?>(
                initialValue: _groundId,
                decoration: const InputDecoration(
                  labelText: 'Ground',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All grounds')),
                  for (final ground in _grounds) DropdownMenuItem(value: ground.id, child: Text(ground.name)),
                ],
                onChanged: (groundId) => _select(groundId: groundId, allGrounds: groundId == null),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              bookings == null
                  ? formatDateLong(_selectedDay)
                  : '${formatDateLong(_selectedDay)} · ${live.length} booking${live.length == 1 ? '' : 's'}'
                      ' · ${formatRupees(total)}',
              style: AppTextStyles.caption,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (bookings == null && _error != null)
                    Column(
                      children: [
                        Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    )
                  else if (bookings == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (bookings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text('No bookings on this day.', style: AppTextStyles.body, textAlign: TextAlign.center),
                    )
                  else
                    for (final booking in bookings) ...[
                      OwnerBookingTile(
                        booking: booking,
                        showGround: _grounds.length > 1 && _groundId == null,
                        onCancel: () => _cancel(booking),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
