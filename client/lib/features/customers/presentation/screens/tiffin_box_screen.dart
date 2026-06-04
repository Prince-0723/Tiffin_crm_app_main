import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/customer_tiffin_api.dart';
import '../../models/customer_tiffin_models.dart';

/// Full-screen tiffin tracking: count, increment/decrement, history.
class TiffinBoxScreen extends StatefulWidget {
  const TiffinBoxScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<TiffinBoxScreen> createState() => _TiffinBoxScreenState();
}

class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const bg = Color(0xFFF0EBFF);
  static const s200 = Color(0xFFE2E8F0);
  static const s500 = Color(0xFF64748B);
  static const s900 = Color(0xFF0F172A);
  static const green = Color(0xFF166534);
  static const greenBg = Color(0xFFF0FDF4);
  static const red = Color(0xFF991B1B);
  static const redBg = Color(0xFFFEF2F2);
}

class _TiffinBoxScreenState extends State<TiffinBoxScreen> {
  static final _histDate = DateFormat('d MMM, h:mm a');

  int _count = 0;
  List<TiffinLedgerEntry> _history = [];
  bool _loading = true;
  String? _error;
  bool _patching = false;

  @override
  void initState() {
    super.initState();
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
        _count = snap.tiffinCount;
        _history = snap.history;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Could not load tiffin data';
      if (e is ApiException) msg = e.message ?? msg;
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  Future<void> _increment() async {
    if (_patching) return;
    setState(() => _patching = true);
    try {
      await CustomerTiffinApi.increment(widget.customerId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  Future<void> _decrement() async {
    if (_patching || _count <= 0) return;
    setState(() => _patching = true);
    try {
      await CustomerTiffinApi.decrement(widget.customerId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
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
              'Tiffin Boxes',
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
              child: CircularProgressIndicator(color: _P.g1, strokeWidth: 2),
            )
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _P.g1,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      Center(
                        child: Text(
                          '$_count',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            color: _P.s900,
                            height: 1,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _patching ? null : _increment,
                              style: FilledButton.styleFrom(
                                backgroundColor: _P.greenBg,
                                foregroundColor: _P.green,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '+ To Collect',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: (_patching || _count <= 0) ? null : _decrement,
                              style: FilledButton.styleFrom(
                                backgroundColor: _P.redBg,
                                foregroundColor: _P.red,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '− Collected',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _P.s900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No history yet.',
                              style: TextStyle(fontSize: 14, color: _P.s500.withValues(alpha: 0.9)),
                            ),
                          ),
                        )
                      else
                        ..._history.map((e) {
                          final inc = e.action.toLowerCase() == 'increment';
                          final when = e.createdAt.millisecondsSinceEpoch == 0
                              ? '—'
                              : _histDate.format(e.createdAt.toLocal());
                          final label = inc ? 'To Collect' : 'Collected';
                          final prefix = inc ? '+1' : '−1';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: inc ? _P.greenBg : _P.redBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: inc
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFCA5A5),
                                  width: 0.5,
                                ),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: inc ? _P.green : _P.red,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '$prefix  ',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(text: '$label  '),
                                    TextSpan(
                                      text: when,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: _P.s500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, color: _P.red, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _P.s500),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _P.g1,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
