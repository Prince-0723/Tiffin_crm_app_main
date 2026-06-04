import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/customer_tiffin_api.dart';
import '../../models/customer_tiffin_models.dart';

/// Full history from GET …/tiffin?history=true — calendar day picker + grouped list.
class TiffinCollectionHistoryScreen extends StatefulWidget {
  const TiffinCollectionHistoryScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<TiffinCollectionHistoryScreen> createState() =>
      _TiffinCollectionHistoryScreenState();
}

class _H {
  static const g1 = Color(0xFF7B3FE4);
  static const bg = Color(0xFFF0EBFF);
  static const s500 = Color(0xFF64748B);
  static const s900 = Color(0xFF0F172A);
  static const green = Color(0xFF166534);
  static const red = Color(0xFF991B1B);
}

class _TiffinCollectionHistoryScreenState
    extends State<TiffinCollectionHistoryScreen> {
  static final _headerFmt = DateFormat('EEEE, d MMMM yyyy');
  static final _timeFmt = DateFormat('h:mm a');

  List<TiffinLedgerEntry> _entries = [];
  bool _loading = true;
  String? _error;

  late DateTime _calendarDay;
  final DateTime _firstCalendarDay = DateTime(2020, 1, 1);
  late DateTime _lastCalendarDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _lastCalendarDay = DateTime(now.year, now.month, now.day);
    _calendarDay = _lastCalendarDay;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await CustomerTiffinApi.fetchWithHistory(widget.customerId);
      if (!mounted) return;
      setState(() {
        _entries = snap.history;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Could not load history';
      if (e is ApiException) msg = e.message ?? msg;
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  List<TiffinLedgerEntry> _entriesOnDay(DateTime day) {
    final t = _dateOnly(day);
    return _entries.where((e) => _dateOnly(e.createdAt.toLocal()) == t).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Days that have at least one entry (for quick chips), newest first.
  List<DateTime> get _daysWithActivity {
    final set = <DateTime>{};
    for (final e in _entries) {
      set.add(_dateOnly(e.createdAt.toLocal()));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Map<DateTime, List<TiffinLedgerEntry>> get _groupedByDay {
    final map = <DateTime, List<TiffinLedgerEntry>>{};
    for (final e in _entries) {
      final d = _dateOnly(e.createdAt.toLocal());
      map.putIfAbsent(d, () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _H.bg,
      appBar: AppBar(
        backgroundColor: _H.g1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.customerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Tiffin collection history',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _H.g1, strokeWidth: 2),
            )
          : _error != null
              ? _ErrorPane(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _H.g1,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Text(
                        'Select a day on the calendar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _H.s500.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.purple.shade100,
                            width: 0.5,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: _calendarDay,
                          firstDate: _firstCalendarDay,
                          lastDate: _lastCalendarDay,
                          onDateChanged: (d) {
                            setState(() {
                              _calendarDay = DateTime(d.year, d.month, d.day);
                            });
                          },
                        ),
                      ),
                      if (_daysWithActivity.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Jump to a day with activity',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _H.s500.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _daysWithActivity.take(12).map((d) {
                            final short = DateFormat('d MMM').format(d);
                            final sel = _dateOnly(_calendarDay) == d;
                            return ActionChip(
                              label: Text(short),
                              onPressed: () {
                                setState(() => _calendarDay = d);
                              },
                              backgroundColor: sel
                                  ? _H.g1.withValues(alpha: 0.2)
                                  : Colors.white,
                              side: BorderSide(
                                color: sel ? _H.g1 : Colors.grey.shade300,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? _H.g1 : _H.s900,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        _headerFmt.format(_calendarDay),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _H.s900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._buildDaySection(_entriesOnDay(_calendarDay)),
                      const SizedBox(height: 28),
                      const Text(
                        'All activity (newest first)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _H.s900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Up to 50 entries from the server',
                        style: TextStyle(
                          fontSize: 11,
                          color: _H.s500.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildFullGroupedList(),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildDaySection(List<TiffinLedgerEntry> dayEntries) {
    if (dayEntries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No collections on this day.',
            style: TextStyle(fontSize: 13, color: _H.s500.withValues(alpha: 0.95)),
          ),
        ),
      ];
    }
    return dayEntries.map<Widget>((e) => _entryTile(e)).toList();
  }

  Widget _entryTile(TiffinLedgerEntry e) {
    final inc = e.action.toLowerCase() == 'increment';
    final label = inc ? 'To Collect' : 'Collected';
    final color = inc ? _H.green : _H.red;
    final when = e.createdAt.millisecondsSinceEpoch == 0
        ? '—'
        : _timeFmt.format(e.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade100, width: 0.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                when,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _H.s900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Text(
              '→ ${e.countAfter}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _H.s500.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFullGroupedList() {
    final grouped = _groupedByDay;
    if (grouped.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No history yet.',
            style: TextStyle(fontSize: 13, color: _H.s500.withValues(alpha: 0.95)),
          ),
        ),
      ];
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final out = <Widget>[];
    for (final d in days) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            _headerFmt.format(d),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _H.g1,
            ),
          ),
        ),
      );
      for (final e in grouped[d]!) {
        out.add(_entryTile(e));
      }
    }
    return out;
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _H.g1),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
