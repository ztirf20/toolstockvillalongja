import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';

class _ReportData {
  final int totalIn;
  final int totalOut;
  final List<({String name, int total})> top;
  const _ReportData(this.totalIn, this.totalOut, this.top);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 30;
  int _seenVersion = -1;
  Future<_ReportData>? _future;

  Future<_ReportData> _load() async {
    final from = DateTime.now().subtract(Duration(days: _days));
    final totals = await DatabaseHelper.instance.getTotals(from);
    final top = await DatabaseHelper.instance.getTopOutgoing(from);
    return _ReportData(totals.totalIn, totals.totalOut, top);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final theme = Theme.of(context);
    if (inv.historyVersion != _seenVersion || _future == null) {
      _seenVersion = inv.historyVersion;
      _future = _load();
    }

    // Inventory valuation grouped by category.
    final byCat = <String, ({int items, int units, double value})>{};
    for (final p in inv.products) {
      final cur = byCat[p.category] ?? (items: 0, units: 0, value: 0.0);
      byCat[p.category] = (
        items: cur.items + 1,
        units: cur.units + p.quantity,
        value: cur.value + p.stockValue,
      );
    }
    final rows = byCat.entries.toList()
      ..sort((a, b) => b.value.value.compareTo(a.value.value));
    final maxValue =
        rows.isEmpty || rows.first.value.value <= 0 ? 1.0 : rows.first.value.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total inventory value',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(money.format(inv.totalValue),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(
                    '${inv.products.length} items • ${inv.totalUnits} units in stock',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Stock movement'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() {
              _days = s.first;
              _future = _load();
            }),
          ),
          const SizedBox(height: 16),
          FutureBuilder<_ReportData>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final d = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TotalCard(
                            label: 'Received',
                            value: d.totalIn,
                            color: Colors.green.shade600,
                            icon: Icons.south_west),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TotalCard(
                            label: 'Sold / removed',
                            value: d.totalOut,
                            color: Colors.red.shade600,
                            icon: Icons.north_east),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Top selling items (units)'),
                  if (d.top.isEmpty)
                    const AppCard(
                        child: Text('No outgoing stock in this period'))
                  else
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                      child: SizedBox(height: 260, child: _TopChart(top: d.top)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionTitle('Stock value by category'),
          if (rows.isEmpty)
            const AppCard(child: Text('No items yet'))
          else
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Row(
                      children: [
                        IconTile(
                            icon: categoryIcon(rows[i].key),
                            color: theme.colorScheme.primary,
                            size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rows[i].key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${rows[i].value.items} items • ${rows[i].value.units} units',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: (rows[i].value.value / maxValue)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(money.format(rows[i].value.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _TotalCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 38),
          const SizedBox(height: 12),
          Text('$value',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TopChart extends StatelessWidget {
  final List<({String name, int total})> top;
  const _TopChart({required this.top});

  /// Picks a tidy step (1, 2, 5, 10, 20, 50, 100...) giving about 4 gridlines.
  double _niceInterval(int maxValue) {
    if (maxValue <= 5) return 1;
    final rough = maxValue / 4;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final step = norm <= 1
        ? 1
        : norm <= 2
            ? 2
            : norm <= 5
                ? 5
                : 10;
    return step * mag;
  }

  String _short(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final maxValue = top.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final interval = _niceInterval(maxValue);
    final maxY = ((maxValue * 1.1) / interval).ceil() * interval;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
        ),
        barGroups: [
          for (var i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: top[i].total.toDouble(),
                  width: 26,
                  color: color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _short(value),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= top.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: SizedBox(
                    width: 64,
                    child: Text(
                      top[i].name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}