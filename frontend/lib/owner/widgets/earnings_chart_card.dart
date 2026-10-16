import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/owner_api.dart';
import '../../core/utils/money.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// (value, button label, "last 14 days" caption) for each view.
const _periods = [
  ('day', 'Daily', 'last 14 days'),
  ('week', 'Weekly', 'last 12 weeks'),
  ('month', 'Monthly', 'last 12 months'),
  ('year', 'Yearly', 'last 5 years'),
];

/// The owner's earnings as bars per day, week, month or year, with the
/// total and how it compares with the periods before. Tap a bar for its
/// exact amount.
class EarningsChartCard extends StatefulWidget {
  /// Where the numbers come from; tests pass sample data.
  final Future<EarningsChart> Function(String period) load;

  const EarningsChartCard({super.key, this.load = OwnerApi.fetchEarnings});

  @override
  State<EarningsChartCard> createState() => _EarningsChartCardState();
}

class _EarningsChartCardState extends State<EarningsChartCard> {
  String _period = 'day';
  EarningsChart? _chart;
  String? _error;
  bool _showTable = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    FutsalApi.bookingsChanged.addListener(_load);
  }

  @override
  void dispose() {
    FutsalApi.bookingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final chart = await widget.load(_period);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _chart = chart;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) setState(() => _error = e.message);
    }
  }

  void _select(String period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _chart = null;
    });
    _load();
  }

  /// Short label under a bar.
  String _axisLabel(DateTime start) => switch (_period) {
        'day' => '${start.day}',
        'week' => '${start.day} ${_months[start.month - 1]}',
        'month' => _months[start.month - 1],
        _ => '${start.year}',
      };

  /// Full label in the tooltip and the table.
  String _fullLabel(DateTime start) {
    switch (_period) {
      case 'day':
        return '${start.day} ${_months[start.month - 1]} ${start.year}';
      case 'week':
        final end = start.add(const Duration(days: 6));
        return '${start.day} ${_months[start.month - 1]} – ${end.day} ${_months[end.month - 1]}';
      case 'month':
        return '${_months[start.month - 1]} ${start.year}';
      default:
        return '${start.year}';
    }
  }

  /// Only some bars get a label so they never crowd.
  bool _labelled(int index, int count) {
    final every = switch (_period) { 'day' => 2, 'week' => 3, 'month' => 2, _ => 1 };
    return (count - 1 - index) % every == 0; // always label the latest bar
  }

  /// "12k" style axis numbers.
  String _compact(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final caption = _periods.firstWhere((p) => p.$1 == _period).$3;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Earnings', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final (value, label, _) in _periods)
                  ButtonSegment(value: value, label: Text(label, style: const TextStyle(fontSize: 12))),
              ],
              selected: {_period},
              onSelectionChanged: (selection) => _select(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          if (chart == null && _error != null)
            Column(
              children: [
                Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            )
          else if (chart == null)
            const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()))
          else ...[
            _Headline(chart: chart, caption: caption),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: _bars(chart)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showTable = !_showTable),
                icon: Icon(_showTable ? Icons.expand_less : Icons.table_rows_outlined, size: 18),
                label: Text(_showTable ? 'Hide numbers' : 'See numbers'),
              ),
            ),
            if (_showTable) _table(chart),
          ],
        ],
      ),
    );
  }

  Widget _bars(EarningsChart chart) {
    final bars = chart.bars;
    final highest = bars.fold<double>(0, (max, bar) => bar.earnings > max ? bar.earnings : max);
    final top = highest == 0 ? 1000.0 : highest * 1.15;
    final width = switch (bars.length) { > 12 => 10.0, > 6 => 14.0, _ => 26.0 };
    final axisText = TextStyle(color: AppColors.textSecondary, fontSize: 10);

    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: top / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: top / 4,
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : SideTitleWidget(meta: meta, child: Text(_compact(value), style: axisText)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= bars.length || !_labelled(index, bars.length)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(meta: meta, child: Text(_axisLabel(bars[index].start), style: axisText));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            tooltipBorderRadius: BorderRadius.circular(8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, rod, __) {
              final bar = bars[group.x];
              return BarTooltipItem(
                '${_fullLabel(bar.start)}\n',
                TextStyle(color: AppColors.surface, fontSize: 11),
                children: [
                  TextSpan(
                    text: formatRupees(bar.earnings),
                    style: TextStyle(color: AppColors.surface, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  TextSpan(
                    text: '\n${bar.games} game${bar.games == 1 ? '' : 's'}',
                    style: TextStyle(color: AppColors.surface, fontSize: 11),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].earnings,
                  width: width,
                  color: AppColors.chartBar,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _table(EarningsChart chart) {
    return Column(
      children: [
        for (final bar in chart.bars.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(child: Text(_fullLabel(bar.start), style: AppTextStyles.body)),
                Text('${bar.games} game${bar.games == 1 ? '' : 's'}', style: AppTextStyles.caption),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Text(formatRupees(bar.earnings),
                      textAlign: TextAlign.right, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The total for the shown periods and the change against the ones before.
class _Headline extends StatelessWidget {
  final EarningsChart chart;
  final String caption;

  const _Headline({required this.chart, required this.caption});

  @override
  Widget build(BuildContext context) {
    final change = chart.changePercent;
    final (IconData icon, String text) = change == null
        ? (Icons.remove, 'nothing to compare with yet')
        : change >= 0
            ? (Icons.arrow_upward, '${change.toStringAsFixed(0)}% more than the $caption before')
            : (Icons.arrow_downward, '${(-change).toStringAsFixed(0)}% less than the $caption before');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatRupees(chart.total),
            style: AppTextStyles.heading.copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
        Text('earned in the $caption', style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(text, style: AppTextStyles.caption)),
          ],
        ),
      ],
    );
  }
}
