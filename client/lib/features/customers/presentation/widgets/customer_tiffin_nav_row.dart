import 'package:flutter/material.dart';

import '../../../../core/utils/error_handler.dart';
import '../../data/customer_tiffin_api.dart';

/// Inline row: icon + label + [−] count [+] on page background (no card).
class CustomerTiffinNavRow extends StatefulWidget {
  const CustomerTiffinNavRow({
    super.key,
    required this.customerId,
    required this.customerName,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 14,
  });

  final String customerId;
  final String customerName;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  @override
  State<CustomerTiffinNavRow> createState() => _CustomerTiffinNavRowState();
}

class _RowP {
  static const s300 = Color(0xFFCBD5E1);
  static const s500 = Color(0xFF64748B);
  static const s900 = Color(0xFF0F172A);
  static const g1 = Color(0xFF7B3FE4);
}

class _CustomerTiffinNavRowState extends State<CustomerTiffinNavRow> {
  int? _count;
  bool _loading = true;
  bool _patching = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
    });
    try {
      final n = await CustomerTiffinApi.fetchCount(widget.customerId);
      if (!mounted) return;
      setState(() {
        _count = n;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _count = null;
        _loading = false;
      });
    }
  }

  Future<void> _increment() async {
    if (_patching) return;
    setState(() => _patching = true);
    try {
      await CustomerTiffinApi.increment(widget.customerId);
      if (!mounted) return;
      await _fetch();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  Future<void> _decrement() async {
    if (_patching) return;
    final c = _count ?? 0;
    if (c <= 0) return;
    setState(() => _patching = true);
    try {
      await CustomerTiffinApi.decrement(widget.customerId);
      if (!mounted) return;
      await _fetch();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  static ButtonStyle _iconBtnStyle({required bool enabled}) {
    return IconButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: enabled ? _RowP.g1 : _RowP.s300,
      disabledForegroundColor: _RowP.s300,
      padding: const EdgeInsets.all(10),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final countLabel =
        _loading ? '…' : (_count != null ? '${_count!}' : '—');
    final canDec =
        !_loading && _count != null && _count! > 0 && !_patching;
    final canInc = !_patching && !_loading;

    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          final sw = MediaQuery.sizeOf(context).width;
          maxW = sw.isFinite ? sw : 560;
        }

        return Container(
          margin: widget.margin,
          width: maxW,
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: _RowP.g1, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tiffin Boxes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _RowP.s900,
                  ),
                ),
              ),
              IconButton(
                onPressed: (canDec && !_patching) ? _decrement : null,
                style: _iconBtnStyle(enabled: canDec && !_patching),
                icon: Icon(
                  Icons.remove_rounded,
                  size: 24,
                  color: canDec && !_patching ? _RowP.g1 : _RowP.s300,
                ),
              ),
              SizedBox(
                width: 40,
                child: Center(
                  child: _patching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _RowP.g1,
                          ),
                        )
                      : Text(
                          countLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _RowP.s900,
                            letterSpacing: -0.5,
                          ),
                        ),
                ),
              ),
              IconButton(
                onPressed: canInc ? _increment : null,
                style: _iconBtnStyle(enabled: canInc),
                icon: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: canInc ? _RowP.g1 : _RowP.s300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
