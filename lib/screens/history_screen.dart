import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 30;

  final _scroll = ScrollController();
  final List<StockMovement> _items = [];
  String _search = '';
  MovementType? _type;
  DateTimeRange? _range;
  bool _loading = false;
  bool _hasMore = true;
  int _seenVersion = -1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    _loading = false;
    _hasMore = true;
    _items.clear();
    if (mounted) setState(() {});
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() => _loading = true);
    final page = await DatabaseHelper.instance.getMovements(
      type: _type,
      search: _search,
      from: _range?.start,
      to: _range == null
          ? null
          : DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23,
              59, 59, 999),
      limit: _pageSize,
      offset: _items.length,
    );
    if (!mounted || gen != _generation) return;
    setState(() {
      _items.addAll(page);
      _hasMore = page.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Reload whenever movements change anywhere in the app.
    final version =
        context.select<InventoryProvider, int>((p) => p.historyVersion);
    if (version != _seenVersion) {
      _seenVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }

    final hasFilters = _type != null || _range != null || _search.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tool or staff name',
                isDense: true,
              ),
              onChanged: (v) {
                _search = v;
                _reload();
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in MovementType.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (sel) {
                        _type = sel ? t : null;
                        _reload();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(_range == null
                        ? 'Date range'
                        : '${_range!.start.month}/${_range!.start.day} – '
                            '${_range!.end.month}/${_range!.end.day}'),
                    onPressed: _pickRange,
                  ),
                ),
                if (hasFilters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                      onPressed: () {
                        _type = null;
                        _range = null;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('No history records found.'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final m = _items[i];
                      final showHeader = i == 0 ||
                          !sameDay(_items[i - 1].timestamp, m.timestamp);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                              child: Text(
                                dayLabel(m.timestamp),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          AppCard(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 3),
                            padding: EdgeInsets.zero,
                            child: MovementTile(movement: m),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}