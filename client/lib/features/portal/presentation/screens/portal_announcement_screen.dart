import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../orders/data/order_api.dart';
import '../../data/portal_announcement_api.dart';

/// Vendor: view and edit the customer portal announcement.
class PortalAnnouncementScreen extends StatefulWidget {
  const PortalAnnouncementScreen({super.key});

  @override
  State<PortalAnnouncementScreen> createState() =>
      _PortalAnnouncementScreenState();
}

class _PortalAnnouncementScreenState extends State<PortalAnnouncementScreen> {
  static final _dateFmt = DateFormat.yMMMd().add_jm();

  String _text = '';
  DateTime? _updatedAt;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final dto = await PortalAnnouncementApi.get();
      if (!mounted) return;
      setState(() {
        _text = dto.text;
        _updatedAt = dto.updatedAt;
        _loading = false;
        _loadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      ErrorHandler.show(context, e);
    }
  }

  /// Opens editor: empty for first message, or pre-filled so saving does not wipe the prior text.
  Future<void> _openAnnouncementEditor() async {
    final hasText = _text.trim().isNotEmpty;
    await _openEditor(initialText: hasText ? _text : '');
  }

  String _ymd(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _openHolidayCancelDeliveries() async {
    var picked = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Cancel deliveries'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This cancels all orders for the selected day that are not yet delivered. '
                'Wallet and subscription balances are only charged when an order is marked delivered, '
                'so cancelled orders are not charged for that day.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(_dateFmt.format(picked)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: picked,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setLocal(() {
                      picked = DateTime(d.year, d.month, d.day);
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel deliveries'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final count = await OrderApi.cancelVendorHoliday(date: _ymd(picked));
      if (!mounted) return;
      AppSnackbar.success(
        context,
        count == 0
            ? 'No active orders to cancel for that day.'
            : 'Cancelled $count delivery order(s).',
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    }
  }

  Future<void> _openEditor({required String initialText}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditAnnouncementSheet(
        initialText: initialText,
        onSaved: (dto) {
          if (!mounted) return;
          setState(() {
            _text = dto.text;
            _updatedAt = dto.updatedAt;
          });
          AppSnackbar.success(
            context,
            'Saved. ${dto.notifiedCount} customers notified.',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Portal Announcement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
          : RefreshIndicator(
              color: AppColors.primaryAccent,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: AppColors.primaryAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Current announcement',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _text.trim().isEmpty
                                ? 'No announcement set'
                                : _text,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: _text.trim().isEmpty
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                              fontStyle: _text.trim().isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          if (_updatedAt != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Last updated: ${_dateFmt.format(_updatedAt!.toLocal())}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            'Only one announcement is stored. Use Edit to change it; saving always replaces the previous message.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openAnnouncementEditor,
                                  icon: Icon(
                                    _text.trim().isEmpty
                                        ? Icons.add_rounded
                                        : Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _text.trim().isEmpty ? 'Add' : 'Edit',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _openHolidayCancelDeliveries,
                            icon: const Icon(Icons.event_busy_rounded, size: 18),
                            label: const Text('Cancel all deliveries (no charge)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cancels undelivered orders for the day you pick. Already-delivered orders stay as-is. '
                            'Meal balance is charged only on delivery, so these cancellations are not charged.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditAnnouncementSheet extends StatefulWidget {
  const _EditAnnouncementSheet({
    required this.initialText,
    required this.onSaved,
  });

  final String initialText;
  final void Function(PortalAnnouncementSaveDto dto) onSaved;

  @override
  State<_EditAnnouncementSheet> createState() => _EditAnnouncementSheetState();
}

class _EditAnnouncementSheetState extends State<_EditAnnouncementSheet> {
  late final TextEditingController _controller;
  bool _notifyAll = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dto = await PortalAnnouncementApi.put(
        text: _controller.text,
        notifyAllCustomers: _notifyAll,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved(dto);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isAdd = widget.initialText.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAdd ? 'Make announcement' : 'Edit announcement',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                maxLines: 8,
                maxLength: 5000,
                decoration: InputDecoration(
                  hintText: 'Announcement text…',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify all customers'),
                value: _notifyAll,
                activeThumbColor: AppColors.primaryAccent,
                inactiveThumbColor: AppColors.textHint,
                inactiveTrackColor: AppColors.surfaceContainerLow,
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primaryAccent
                          : AppColors.border,
                ),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _notifyAll = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
