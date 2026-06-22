// ignore_for_file: unused_field

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../screens/customer_details/customer_details_screen.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../dashboard/overview_dashboard_refresh_signal.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/lottie_empty_state.dart';
import '../../../../models/customer_model.dart';
import '../../../../services/pdf_download_service.dart';
import '../../data/customer_api.dart';
import '../../../profile/data/profile_api.dart';
import '../../../zones/data/zone_api.dart';
import '../../../zones/models/zone_model.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const v700 = Color(0xFF5B21B6);
  static const v100 = Color(0xFFEDE9FE);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
  static const s400 = Color(0xFF94A3B8);
  static const s300 = Color(0xFFCBD5E1);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
  static const bg = Color(0xFFF0EBFF);

  static const greenBg = Color(0xFFF0FDF4);

  static const greenTxt = Color(0xFF166534);

  static const greenBdr = Color(0xFF86EFAC);
  static const redBg = Color(0xFFFEF2F2);
  static const redTxt = Color(0xFF991B1B);
  static const redBdr = Color(0xFFFCA5A5);

  static const amberBg = Color(0xFFFFFBEB);

  static const amberTxt = Color(0xFF92400E);
  static const amberBdr = Color(0xFFFCD34D);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

Color _accentColor(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'active':
      return _P.green;
    case 'inactive':
      return _P.red;
    default:
      return _P.amber;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

enum _CustomerSort {
  newest,
  oldest,
  nameAz,
  nameZa,
  lowestBalance,
  highestBalance,
  lowestTiffinCounts,
  highestTiffinCounts,
}

enum _CustomerStatusFilter {
  lowBalance,
  vegetarian,
  nonVegetarian,
  active,
  paused,
  blocked,
  inactiveMeals,
  customizedMeals,
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  // ── ALL LOGIC UNCHANGED ──
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  String _filter = 'active';
  int _page = 1;
  static const int _limit = 20;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<CustomerModel> _customers = [];

  // ── Added local-only sort/filter state (does not affect API fetching) ──
  _CustomerSort _sort = _CustomerSort.newest;
  final Set<_CustomerStatusFilter> _statusFilters = <_CustomerStatusFilter>{};
  final Set<String> _timeSlotFilters = <String>{};
  List<ZoneModel> _zones = [];
  bool _zonesLoading = false;
  String? _selectedZoneId;

  // ── New: card field customization (local-only UI preference) ──
  static const String _prefsKeyCardFields = 'customers.card_fields.v1';
  Set<_CardField> _cardFields = <_CardField>{
    _CardField.name,
    _CardField.phone,
    _CardField.area,
    _CardField.balance,
  };

  String? _businessName;
  String? _businessPhone;
  Map<String, String> _customerLabels = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadZones();
    _loadCardPrefs();
    _loadBusinessProfile();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCardPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKeyCardFields);
      if (raw == null || raw.isEmpty) return;
      final parsed = raw
          .map(_CardFieldX.tryParse)
          .whereType<_CardField>()
          .toSet();
      if (parsed.isEmpty) return;
      if (!mounted) return;
      setState(() => _cardFields = parsed);
    } catch (_) {}
  }

  Future<void> _saveCardPrefs(Set<_CardField> next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKeyCardFields,
        next.map((e) => e.key).toList(),
      );
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _loadZones() async {
    setState(() => _zonesLoading = true);
    try {
      final list = await ZoneApi.list(limit: 100, isActive: true);
      if (mounted) setState(() => _zones = list);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load zones: $e');
    } finally {
      if (mounted) setState(() => _zonesLoading = false);
    }
  }

  Future<void> _loadCustomers({bool reset = true}) async {
    if (_isLoading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    try {
      final result = await CustomerApi.list(
        page: 1,
        limit: _limit,
        status: _filter == 'all'
            ? null
            : (_filter == 'lowBalance' ? null : _filter),
        lowBalance: _filter == 'lowBalance',
        zoneId: _selectedZoneId,
      );
      List<dynamic> rawList = [];
      int total = 0;
      if (result['data'] is Map) {
        final inner = result['data'] as Map<String, dynamic>;
        rawList = inner['data'] as List? ?? [];
        total = inner['total'] as int? ?? rawList.length;
      } else if (result['data'] is List) {
        rawList = result['data'] as List;
        total = result['total'] as int? ?? rawList.length;
      } else if (result['customers'] is List) {
        rawList = result['customers'] as List;
        total = result['total'] as int? ?? rawList.length;
      }
      final list = rawList
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _customers = list;
        _hasMore = list.length >= _limit && list.length < total;
        _page = 1;
      });
      await _loadAllLabels();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ _loadCustomers error: $e\n$stack');
      }
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await CustomerApi.list(
        page: nextPage,
        limit: _limit,
        status: _filter == 'all'
            ? null
            : (_filter == 'lowBalance' ? null : _filter),
        lowBalance: _filter == 'lowBalance',
        zoneId: _selectedZoneId,
      );
      List<dynamic> rawList = [];
      int total = 0;
      if (result['data'] is Map) {
        final inner = result['data'] as Map<String, dynamic>;
        rawList = inner['data'] as List? ?? [];
        total = inner['total'] as int? ?? rawList.length;
      } else if (result['data'] is List) {
        rawList = result['data'] as List;
        total = result['total'] as int? ?? rawList.length;
      } else if (result['customers'] is List) {
        rawList = result['customers'] as List;
        total = result['total'] as int? ?? rawList.length;
      }
      final list = rawList
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _customers = [..._customers, ...list];
        _page = nextPage;
        _hasMore = _customers.length < total;
      });
      await _loadAllLabels();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('_loadMore error: $e\n$stack');
      }
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    await _loadZones();
    await _loadCustomers(reset: true);
  }

  Future<void> _openAddCustomer() async {
    final created = await context.push<CustomerModel>(AppRoutes.addCustomer);
    if (!mounted || created == null) return;

    final shouldShow =
        _filter == 'all' || _filter == 'active' || created.status == _filter;
    if (shouldShow) {
      setState(() {
        final withoutDuplicate = _customers
            .where((customer) => customer.id != created.id)
            .toList();
        _customers = [created, ...withoutDuplicate];
      });
      await _loadAllLabels();
    }
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final data = await ProfileApi.getMe();
      if (!mounted) return;
      setState(() {
        _businessName =
            data['businessName']?.toString() ??
            data['tiffinCenterName']?.toString() ??
            '';
        _businessPhone = data['phone']?.toString() ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadAllLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labels = <String, String>{};
      for (final c in _customers) {
        final id = c.id.trim();
        if (id.isEmpty) continue;
        final val = prefs.getString('customer_label_$id');
        if (val != null && val.trim().isNotEmpty) {
          labels[id] = val.trim();
        }
      }
      if (mounted) setState(() => _customerLabels = labels);
    } catch (_) {}
  }

  /// Safe map read for list build (avoids odd JS interop edge cases with empty keys).
  String? _labelForCustomer(String id) {
    final k = id.trim();
    if (k.isEmpty) return null;
    return _customerLabels[k];
  }

  Future<void> _saveLabel(String customerId, String label) async {
    final id = customerId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('customer_label_$id');
      if (mounted) {
        setState(() => _customerLabels.remove(id));
      }
      return;
    }
    await prefs.setString('customer_label_$id', trimmed);
    if (mounted) {
      setState(() => _customerLabels[id] = trimmed);
    }
  }

  static const _labelPresets = [
    'VIP Customer',
    'Regular',
    'New Customer',
    'Due Payment',
  ];

  Future<void> _openLabelSheet(
    BuildContext context,
    CustomerModel customer,
  ) async {
    const bg = Colors.white;
    const divider = _P.s200;
    final current = _labelForCustomer(customer.id);
    final String initialSelected;
    if (current != null && current.isNotEmpty) {
      initialSelected = _labelPresets.contains(current) ? current : '';
    } else {
      initialSelected = 'Regular';
    }
    final customCtrl = TextEditingController(
      text:
          (current != null &&
              current.isNotEmpty &&
              !_labelPresets.contains(current))
          ? current
          : '',
    );
    String selected = initialSelected;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.label_outline_rounded,
                                color: _P.v700,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Label — ${customer.name}',
                                  style: const TextStyle(
                                    color: _P.s900,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: _P.s600,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          if ((_businessName ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _P.v100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFDDD6FE),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _businessName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _P.v700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            'Quick tags',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _P.s600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in _labelPresets)
                                FilterChip(
                                  label: Text(
                                    p,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected == p
                                          ? Colors.white
                                          : _P.v700,
                                    ),
                                  ),
                                  selected: selected == p,
                                  onSelected: (_) {
                                    setModal(() {
                                      selected = p;
                                      customCtrl.clear();
                                    });
                                  },
                                  selectedColor: _P.g1,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFFDDD6FE),
                                    width: 0.5,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Custom label',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _P.s600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: customCtrl,
                            onChanged: (_) {
                              setModal(() {
                                selected = '';
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Type a custom tag…',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: _P.s400,
                              ),
                              filled: true,
                              fillColor: _P.s100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: divider),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: divider),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: _P.v700,
                                  width: 1,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: _P.s900,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await _saveLabel(customer.id, '');
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      AppSnackbar.success(
                                        context,
                                        'Label cleared',
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _P.s600,
                                    side: const BorderSide(color: divider),
                                  ),
                                  child: const Text('Clear'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: () async {
                                    final value =
                                        customCtrl.text.trim().isNotEmpty
                                        ? customCtrl.text.trim()
                                        : (selected.isNotEmpty
                                              ? selected
                                              : 'Regular');
                                    await _saveLabel(customer.id, value);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      AppSnackbar.success(
                                        context,
                                        'Label applied',
                                      );
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _P.g1,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Apply',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    customCtrl.dispose();
  }

  Future<void> _openPrintCopiesSheet(
    BuildContext context,
    CustomerModel customer,
  ) async {
    int copies = 1;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _P.s200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.print_outlined,
                            color: _P.v700,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Print Tiffin Label',
                              style: TextStyle(
                                color: _P.s900,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _P.s600,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _P.s600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RadioListTile<int>(
                        title: const Text(
                          '1 copy (top-left, rest blank)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: 1,
                        groupValue: copies,
                        onChanged: (v) => setModal(() => copies = v ?? 1),
                      ),
                      RadioListTile<int>(
                        title: const Text(
                          '4 copies (full A4, save paper)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: 4,
                        groupValue: copies,
                        onChanged: (v) => setModal(() => copies = v ?? 4),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _printTiffinLabel(
                            context,
                            customer,
                            copies: copies,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _P.g1,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Generate PDF',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _printTiffinLabel(
    BuildContext context,
    CustomerModel customer, {
    int copies = 1,
  }) async {
    try {
      final businessName = (_businessName ?? '').trim().isEmpty
          ? 'My Tiffin Center'
          : _businessName!.trim();
      final businessPhone = (_businessPhone ?? '').trim();
      final label = _labelForCustomer(customer.id);
      final address = [
        customer.address ?? '',
        customer.area ?? '',
      ].where((s) => s.trim().isNotEmpty).join(', ');
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final headerPurple = PdfColor.fromHex('#5B21B6');
      final chipPurple = PdfColor.fromHex('#5B21B6');

      pw.Widget buildLabel() {
        return pw.Container(
          margin: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: PdfColors.grey500,
              width: 0.8,
              style: pw.BorderStyle.dashed,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: headerPurple,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(5),
                    topRight: pw.Radius.circular(5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (businessPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Ph: $businessPhone',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TO:',
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      customer.name,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        address,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Ph: ${customer.phone}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (label != null && label.isNotEmpty)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: chipPurple,
                                width: 0.8,
                              ),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              label,
                              style: pw.TextStyle(
                                color: chipPurple,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          pw.SizedBox(),
                        pw.Text(
                          'Date: $dateStr',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final pdf = pw.Document();
      final slots = <pw.Widget>[];
      for (var i = 0; i < copies; i++) {
        slots.add(buildLabel());
      }
      while (slots.length < 4) {
        slots.add(pw.SizedBox());
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) {
            return pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(child: slots[0]),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: slots[1]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(child: slots[2]),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: slots[3]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final ymd =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final labelFileName = 'Label_${customer.id}_$ymd.pdf';
      if (context.mounted) {
        await PdfDownloadService.saveBytesAndOpen(
          context: context,
          bytes: Uint8List.fromList(bytes),
          fileName: labelFileName,
        );
      }
    } catch (e) {
      if (context.mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _openCustomerRowMenu(CustomerModel customer) async {
    const bg = Colors.white;
    const divider = _P.s200;
    const text = _P.s900;

    Widget item({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? iconColor,
      Color? textColor,
    }) {
      return InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? _P.v700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor ?? text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _P.s400, size: 18),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              color: text,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _P.s600,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: divider),
                  item(
                    icon: Icons.label_outline_rounded,
                    label: 'Label Customer',
                    onTap: () => _openLabelSheet(context, customer),
                  ),
                  item(
                    icon: Icons.print_outlined,
                    label: 'Print Tiffin Label',
                    onTap: () => _openPrintCopiesSheet(context, customer),
                  ),
                  item(
                    icon: Icons.edit_outlined,
                    label: 'Edit Customer',
                    onTap: () async {
                      await context.push(
                        AppRoutes.editCustomer,
                        extra: customer,
                      );
                      _loadCustomers(reset: true);
                    },
                  ),
                  item(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    onTap: () => WhatsAppHelper.openChat(customer.phone),
                  ),
                  item(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    iconColor: _P.redTxt,
                    textColor: _P.redTxt,
                    onTap: () => _confirmDelete(context, customer),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _confirmDelete(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Customer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _P.s900,
          ),
        ),
        content: Text(
          'Delete ${customer.name}? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _P.s600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await CustomerApi.delete(customer.id);
                DeliveryTrackingSocket.instance.notifyDailyOrdersChanged();
                overviewDashboardTabSelectedTick.value++;
                if (context.mounted) {
                  AppSnackbar.success(context, 'Customer deleted');
                  _loadCustomers(reset: true);
                }
              } catch (e) {
                if (context.mounted) ErrorHandler.show(context, e);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _P.redBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _P.redBdr, width: 0.5),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: _P.redTxt,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _filterLabels = ['All', 'Active', 'Inactive', 'Low Balance'];
  static const _filterValues = ['all', 'active', 'inactive', 'lowBalance'];

  String _mainFilterLabel() {
    final i = _filterValues.indexOf(_filter);
    final label = (i >= 0) ? _filterLabels[i] : 'All';
    return 'Filter ($label)';
  }

  Future<void> _openMainFilterSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(String value, String label) {
          final sel = _filter == value;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _filter = value);
              _loadCustomers(reset: true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? _P.g1 : _P.s400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel ? _P.s900 : _P.s600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter',
                            style: TextStyle(
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _P.s600,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: _P.s200),
                  item('all', 'All'),
                  Container(height: 1, color: _P.s200),
                  item('active', 'Active'),
                  Container(height: 1, color: _P.s200),
                  item('inactive', 'Inactive'),
                  Container(height: 1, color: _P.s200),
                  item('lowBalance', 'Low Balance'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _sheetBg = Color(0xFF1E1E1E);
  static const _sheetBorder = Color(0x33FFFFFF);

  static bool _isLowBalance(CustomerModel c) =>
      c.effectiveSubscriptionBalance < 100;

  static String? _diet(CustomerModel c) {
    final dt = c.dietType?.trim().toLowerCase();
    if (dt != null && dt.isNotEmpty) return dt;
    final tags = (c.tags ?? const [])
        .map((e) => e.trim().toLowerCase())
        .toList();
    if (tags.contains('veg') || tags.contains('vegetarian')) return 'veg';
    if (tags.contains('non_veg') ||
        tags.contains('non-veg') ||
        tags.contains('nonvegetarian')) {
      return 'non_veg';
    }
    return null;
  }

  static bool _hasInactiveMeals(CustomerModel c) {
    if (c.hasInactiveMeals == true) return true;
    final tags = (c.tags ?? const []).map((e) => e.trim().toLowerCase());
    return tags.contains('inactive_meals') || tags.contains('inactive-meals');
  }

  static bool _hasCustomizedMeals(CustomerModel c) {
    if (c.hasCustomizedMeals == true) return true;
    final tags = (c.tags ?? const []).map((e) => e.trim().toLowerCase());
    return tags.contains('customized_meals') ||
        tags.contains('custom-meals') ||
        tags.contains('customized');
  }

  static Set<String> _customerTimeSlots(CustomerModel c) {
    final out = <String>{};
    for (final s in c.timeSlots ?? const <String>[]) {
      final v = s.trim();
      if (v.isNotEmpty) out.add(v);
    }
    // Also allow tags to contribute if backend uses tags for slots.
    for (final t in c.tags ?? const <String>[]) {
      final v = t.trim();
      if (v.isNotEmpty &&
          (v.toLowerCase().contains('morning') ||
              v.toLowerCase().contains('afternoon') ||
              v.toLowerCase().contains('evening') ||
              v.toLowerCase().contains('breakfast') ||
              v.toLowerCase().contains('lunch') ||
              v.toLowerCase().contains('dinner'))) {
        out.add(v);
      }
    }
    return out;
  }

  static int _tiffinCount(CustomerModel c) => c.tiffinCount ?? 0;

  List<CustomerModel> _applyLocalFiltersAndSort(List<CustomerModel> base) {
    final statusSel = _statusFilters;
    final timeSel = _timeSlotFilters;

    bool statusMatches(CustomerModel c) {
      if (statusSel.isEmpty) return true; // means "all 8/8"
      bool any = false;
      for (final f in statusSel) {
        switch (f) {
          case _CustomerStatusFilter.lowBalance:
            any = any || _isLowBalance(c);
            break;
          case _CustomerStatusFilter.vegetarian:
            any = any || (_diet(c) == 'veg' || _diet(c) == 'vegetarian');
            break;
          case _CustomerStatusFilter.nonVegetarian:
            any =
                any ||
                (_diet(c) == 'non_veg' ||
                    _diet(c) == 'nonveg' ||
                    _diet(c) == 'non-veg');
            break;
          case _CustomerStatusFilter.active:
            any = any || c.status.toLowerCase() == 'active';
            break;
          case _CustomerStatusFilter.paused:
            any = any || c.status.toLowerCase() == 'paused';
            break;
          case _CustomerStatusFilter.blocked:
            any = any || c.status.toLowerCase() == 'blocked';
            break;
          case _CustomerStatusFilter.inactiveMeals:
            any = any || _hasInactiveMeals(c);
            break;
          case _CustomerStatusFilter.customizedMeals:
            any = any || _hasCustomizedMeals(c);
            break;
        }
      }
      return any;
    }

    bool timeMatches(CustomerModel c) {
      if (timeSel.isEmpty) return true;
      final slots = _customerTimeSlots(c).map((e) => e.toLowerCase()).toSet();
      for (final s in timeSel) {
        if (slots.contains(s.toLowerCase())) return true;
      }
      return false;
    }

    final out = base.where((c) => statusMatches(c) && timeMatches(c)).toList();

    int cmpString(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    out.sort((a, b) {
      switch (_sort) {
        case _CustomerSort.newest:
          return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _CustomerSort.oldest:
          return (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _CustomerSort.nameAz:
          return cmpString(a.name, b.name);
        case _CustomerSort.nameZa:
          return cmpString(b.name, a.name);
        case _CustomerSort.lowestBalance:
          return a.effectiveSubscriptionBalance
              .compareTo(b.effectiveSubscriptionBalance);
        case _CustomerSort.highestBalance:
          return b.effectiveSubscriptionBalance
              .compareTo(a.effectiveSubscriptionBalance);
        case _CustomerSort.lowestTiffinCounts:
          return _tiffinCount(a).compareTo(_tiffinCount(b));
        case _CustomerSort.highestTiffinCounts:
          return _tiffinCount(b).compareTo(_tiffinCount(a));
      }
    });
    return out;
  }

  String _sortLabel() {
    final label = switch (_sort) {
      _CustomerSort.newest => 'Newest',
      _CustomerSort.oldest => 'Oldest',
      _CustomerSort.nameAz => 'Name (A-Z)',
      _CustomerSort.nameZa => 'Name (Z-A)',
      _CustomerSort.lowestBalance => 'Lowest Balance',
      _CustomerSort.highestBalance => 'Highest Balance',
      _CustomerSort.lowestTiffinCounts => 'Lowest Tiffin Counts',
      _CustomerSort.highestTiffinCounts => 'Highest Tiffin Counts',
    };
    return 'Sort By ($label)';
  }

  String _statusLabel() {
    final sel = _statusFilters.isEmpty
        ? _CustomerStatusFilter.values.length
        : _statusFilters.length;
    return 'Status ($sel/${_CustomerStatusFilter.values.length})';
  }

  String _timeSlotsLabel() {
    return _timeSlotFilters.isEmpty
        ? 'Time Slots'
        : 'Time Slots (${_timeSlotFilters.length})';
  }

  String _zoneLabel() {
    if (_zonesLoading) return 'Zone (…)';
    if (_selectedZoneId == null) return 'Zone (All)';
    for (final z in _zones) {
      if (z.id == _selectedZoneId) return 'Zone (${z.name})';
    }
    return 'Zone (Selected)';
  }

  Future<void> _openZoneSheet(BuildContext context) async {
    if (_zones.isEmpty && !_zonesLoading) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(String? zoneId, String label) {
          final sel = _selectedZoneId == zoneId;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _selectedZoneId = zoneId);
              _loadCustomers(reset: true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? _P.g1 : _P.s400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel ? _P.s900 : _P.s600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Zone',
                            style: TextStyle(
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedZoneId = null);
                            _loadCustomers(reset: true);
                          },
                          child: const Text(
                            'Clear Selection',
                            style: TextStyle(
                              color: _P.v700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _P.s600,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: _P.s200),
                  if (_zonesLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _P.g1,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_zones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No zones available',
                        style: TextStyle(
                          color: _P.s500,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    item(null, 'All Zones'),
                    for (var i = 0; i < _zones.length; i++) ...[
                      Container(height: 1, color: _P.s200),
                      item(_zones[i].id, _zones[i].name),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dropdownPill({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.s300, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _P.s600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: _P.s600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSortSheet(
    BuildContext context,
    List<CustomerModel> base,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget option(_CustomerSort v, String label) {
          final selected = _sort == v;
          return GestureDetector(
            onTap: () {
              setState(() => _sort = v);
              Navigator.pop(ctx);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _P.g1 : _P.s200,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _P.v700 : _P.s900,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        final mq = MediaQuery.of(ctx);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: mq.size.height * 0.74, // prevents bottom overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sort By',
                            style: TextStyle(
                              color: _P.s900,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _sort = _CustomerSort.newest);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Clear Selection',
                            style: TextStyle(
                              color: _P.v700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.8, color: _P.s200),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        mq.padding.bottom + 16,
                      ),
                      children: [
                        option(_CustomerSort.newest, 'Newest'),
                        option(_CustomerSort.oldest, 'Oldest'),
                        option(_CustomerSort.nameAz, 'Name (A-Z)'),
                        option(_CustomerSort.nameZa, 'Name (Z-A)'),
                        option(_CustomerSort.lowestBalance, 'Lowest Balance'),
                        option(_CustomerSort.highestBalance, 'Highest Balance'),
                        option(
                          _CustomerSort.lowestTiffinCounts,
                          'Lowest Tiffin Counts',
                        ),
                        option(
                          _CustomerSort.highestTiffinCounts,
                          'Highest Tiffin Counts',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStatusSheet(
    BuildContext context,
    List<CustomerModel> base,
  ) async {
    Map<_CustomerStatusFilter, int> counts() {
      int countWhere(bool Function(CustomerModel c) pred) =>
          base.where(pred).length;
      return <_CustomerStatusFilter, int>{
        _CustomerStatusFilter.lowBalance: countWhere(_isLowBalance),
        _CustomerStatusFilter.vegetarian: countWhere(
          (c) => _diet(c) == 'veg' || _diet(c) == 'vegetarian',
        ),
        _CustomerStatusFilter.nonVegetarian: countWhere(
          (c) =>
              _diet(c) == 'non_veg' ||
              _diet(c) == 'nonveg' ||
              _diet(c) == 'non-veg',
        ),
        _CustomerStatusFilter.active: countWhere(
          (c) => c.status.toLowerCase() == 'active',
        ),
        _CustomerStatusFilter.paused: countWhere(
          (c) => c.status.toLowerCase() == 'paused',
        ),
        _CustomerStatusFilter.blocked: countWhere(
          (c) => c.status.toLowerCase() == 'blocked',
        ),
        _CustomerStatusFilter.inactiveMeals: countWhere(_hasInactiveMeals),
        _CustomerStatusFilter.customizedMeals: countWhere(_hasCustomizedMeals),
      };
    }

    final cMap = counts();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        Widget option(_CustomerStatusFilter v, String label) {
          final selected = _statusFilters.contains(v);
          final c = cMap[v] ?? 0;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _statusFilters.remove(v);
                } else {
                  _statusFilters.add(v);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _P.g1 : _P.s200,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label ($c)',
                      style: TextStyle(
                        color: selected ? _P.v700 : _P.s900,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_rounded, color: _P.v700, size: 18),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: _P.s900,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _statusFilters.clear());
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Clear Selection',
                      style: TextStyle(
                        color: _P.v700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              option(_CustomerStatusFilter.lowBalance, 'Low Balance'),
              option(_CustomerStatusFilter.vegetarian, 'Vegetarian'),
              option(_CustomerStatusFilter.nonVegetarian, 'Non Vegetarian'),
              option(_CustomerStatusFilter.active, 'Active'),
              option(_CustomerStatusFilter.paused, 'Paused'),
              option(_CustomerStatusFilter.blocked, 'Blocked'),
              option(_CustomerStatusFilter.inactiveMeals, 'Inactive Meals'),
              option(_CustomerStatusFilter.customizedMeals, 'Customized Meals'),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: _P.g1,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTimeSlotsSheet(
    BuildContext context,
    List<CustomerModel> base,
  ) async {
    final allSlots = <String, int>{};
    for (final c in base) {
      for (final s in _customerTimeSlots(c)) {
        final key = s.trim();
        if (key.isEmpty) continue;
        allSlots[key] = (allSlots[key] ?? 0) + 1;
      }
    }
    final keys = allSlots.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        Widget option(String slot) {
          final selected = _timeSlotFilters.contains(slot);
          final c = allSlots[slot] ?? 0;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _timeSlotFilters.remove(slot);
                } else {
                  _timeSlotFilters.add(slot);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _P.g1 : _P.s200,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$slot ($c)',
                      style: TextStyle(
                        color: selected ? _P.v700 : _P.s900,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_rounded, color: _P.v700, size: 18),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Time Slots',
                      style: TextStyle(
                        color: _P.s900,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _timeSlotFilters.clear());
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Clear Selection',
                      style: TextStyle(
                        color: _P.v700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (keys.isEmpty)
                const Text(
                  'No time slots found',
                  style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
                )
              else
                ...keys.map(option),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: _P.g1,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 3-dot menu + actions (local-only, uses already loaded customers) ──

  Future<void> _openMoreMenu(List<CustomerModel> current) async {
    const bg = Colors.white;
    const card = Colors.white;
    const divider = _P.s200;
    const text = _P.s900;

    Widget item({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: _P.v700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _P.s400, size: 18),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: card,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Customers',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _P.s600,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.settings_outlined,
                    label: 'Customize Card Info',
                    onTap: _openCustomizeCardInfo,
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.download_rounded,
                    label: 'Download Backup',
                    onTap: () => _openDownloadBackup(current),
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.donut_large_rounded,
                    label: 'Customer Analytics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            _CustomerAnalyticsScreen(customers: current),
                      ),
                    ),
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.inventory_2_outlined,
                    label: 'Archived Customers',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ArchivedCustomersScreen(),
                      ),
                    ),
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.upload_rounded,
                    label: 'Import Bulk Data',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ImportCustomersScreen(
                          onImported: (items) {
                            setState(
                              () => _customers = [...items, ..._customers],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.info_outline_rounded,
                    label: 'Learn More',
                    onTap: _openLearnMore,
                  ),
                  Container(height: 1, color: divider),
                  item(
                    icon: Icons.lock_outline_rounded,
                    label: 'Total Tiffins Outside',
                    onTap: () => _openTotalTiffinsOutside(current),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCustomizeCardInfo() async {
    const bg = Colors.white;
    const divider = _P.s200;
    var temp = Set<_CardField>.from(_cardFields);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Widget row(_CardField f) {
              final sel = temp.contains(f);
              return InkWell(
                onTap: () => setModal(() {
                  if (sel) {
                    if (temp.length > 1) temp.remove(f);
                  } else {
                    temp.add(f);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: sel,
                        onChanged: (_) => setModal(() {
                          if (sel) {
                            if (temp.length > 1) temp.remove(f);
                          } else {
                            temp.add(f);
                          }
                        }),
                        activeColor: _P.g1,
                        checkColor: Colors.white,
                        side: const BorderSide(color: _P.s300, width: 1),
                      ),
                      Expanded(
                        child: Text(
                          f.label,
                          style: const TextStyle(
                            color: _P.s900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Customize Card Info',
                                style: TextStyle(
                                  color: _P.s900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setModal(() {
                                temp = <_CardField>{
                                  _CardField.name,
                                  _CardField.phone,
                                  _CardField.area,
                                  _CardField.balance,
                                };
                              }),
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  color: _P.v700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: divider),
                      row(_CardField.name),
                      row(_CardField.phone),
                      row(_CardField.area),
                      row(_CardField.balance),
                      Container(height: 1, color: divider),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              setState(() => _cardFields = temp);
                              await _saveCardPrefs(temp);
                              if (context.mounted) Navigator.pop(ctx);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _P.g1,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDownloadBackup(List<CustomerModel> current) async {
    const bg = Colors.white;
    const divider = _P.s200;
    const subText = _P.s600;

    Future<void> saveCsv() async {
      final header = [
        'Name',
        'Phone',
        'Address',
        'Zone',
        'Remaining Balance',
        'Status',
        'Meal Plan',
        'Time Slot',
      ];
      String esc(String v) {
        final s = v.replaceAll('"', '""');
        return '"$s"';
      }

      final lines = <String>[header.map(esc).join(',')];
      for (final c in current) {
        final slots = (c.timeSlots ?? const <String>[]).join(' | ');
        final addr = [
          c.address ?? '',
          c.area ?? '',
        ].where((e) => e.trim().isNotEmpty).join(', ');
        lines.add(
          [
            c.name,
            c.phone,
            addr,
            c.area ?? '',
            c.effectiveSubscriptionBalance.toStringAsFixed(2),
            c.status,
            (c.tags ?? const <String>[]).join(' | '),
            slots,
          ].map((e) => esc(e.toString())).join(','),
        );
      }

      final bytes = Uint8List.fromList(lines.join('\n').codeUnits);
      await FileSaver.instance.saveFile(
        name: 'customers_backup_${DateTime.now().millisecondsSinceEpoch}.csv',
        bytes: bytes,
        mimeType: MimeType.csv,
      );
      if (mounted) {
        AppSnackbar.success(context, 'Backup downloaded successfully');
      }
    }

    Future<void> savePdf() async {
      final doc = pw.Document();
      final now = DateTime.now();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return [
              pw.Text(
                'TiffinCRM — Customers Backup',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated on ${now.day}/${now.month}/${now.year}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Name',
                  'Phone',
                  'Address/Zone',
                  'Remaining Balance',
                  'Status',
                  'Time Slot',
                ],
                data: [
                  for (final c in current)
                    [
                      c.name,
                      c.phone,
                      '${c.address ?? ''} ${c.area ?? ''}'.trim(),
                      '₹${c.effectiveSubscriptionBalance.toStringAsFixed(2)}',
                      c.status,
                      (c.timeSlots ?? const <String>[]).join(' | '),
                    ],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
              ),
            ];
          },
        ),
      );
      final bytes = await doc.save();
      final backupName =
          'CustomersBackup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
      await PdfDownloadService.saveBytesAndOpen(
        context: context,
        bytes: Uint8List.fromList(bytes),
        fileName: backupName,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Download Backup',
                            style: TextStyle(
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: divider),
                  ListTile(
                    leading: const Icon(
                      Icons.table_view_rounded,
                      color: _P.v700,
                    ),
                    title: const Text(
                      'Download as CSV/Excel',
                      style: TextStyle(
                        color: _P.s900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Exports current loaded customers',
                      style: TextStyle(color: subText),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await saveCsv();
                    },
                  ),
                  Container(height: 1, color: divider),
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _P.v700,
                    ),
                    title: const Text(
                      'Download as PDF',
                      style: TextStyle(
                        color: _P.s900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Generates a clean PDF table',
                      style: TextStyle(color: subText),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await savePdf();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLearnMore() async {
    const bg = Colors.white;
    const divider = _P.s200;
    const subText = _P.s600;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learn More',
                  style: TextStyle(
                    color: _P.s900,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Customers helps you manage zones, meal plans, balances and delivery timing.\n\n'
                  '- Use filters to find active/paused/blocked customers.\n'
                  '- Use Time Slots to group delivery timings.\n'
                  '- Low balance helps you track who needs recharge.\n'
                  '- Swipe a customer to Edit, Chat or Delete.\n',
                  style: TextStyle(
                    color: subText,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTotalTiffinsOutside(List<CustomerModel> current) {
    final outside = current.where((c) => (c.tiffinCount ?? 0) > 0).toList()
      ..sort((a, b) => (b.tiffinCount ?? 0).compareTo(a.tiffinCount ?? 0));
    final total = outside.fold<int>(0, (s, c) => s + (c.tiffinCount ?? 0));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TiffinsOutsideScreen(customers: outside, total: total),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searched = _query.isEmpty
        ? _customers
        : _customers.where((c) {
            final q = _query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.phone.contains(_query) ||
                (c.email?.toLowerCase().contains(q) ?? false);
          }).toList();

    final filtered = _applyLocalFiltersAndSort(searched);

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customers',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${_customers.where((c) => c.status == "active").length} active',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _isLoading ? null : _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => _openMoreMenu(filtered),
            tooltip: 'More',
          ),
        ],
      ),

      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // ── Search + filter chips ──
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _P.s100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _P.s200, width: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  size: 16,
                                  color: _P.s400,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _P.s900,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search name, phone, email…',
                                      hintStyle: const TextStyle(
                                        fontSize: 13,
                                        color: _P.s400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                  ),
                                ),
                                if (_query.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: _P.s400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Added: Sort / Status / Time Slot dropdown pills (local-only)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        _dropdownPill(
                          label: _sortLabel(),
                          onTap: () => _openSortSheet(context, searched),
                        ),
                        const SizedBox(width: 8),
                        _dropdownPill(
                          label: _mainFilterLabel(),
                          onTap: () => _openMainFilterSheet(context),
                        ),
                        const SizedBox(width: 8),
                        _dropdownPill(
                          label: _statusLabel(),
                          onTap: () => _openStatusSheet(context, searched),
                        ),
                        const SizedBox(width: 8),
                        _dropdownPill(
                          label: _timeSlotsLabel(),
                          onTap: () => _openTimeSlotsSheet(context, searched),
                        ),
                        if (_zones.isNotEmpty || _zonesLoading) ...[
                          const SizedBox(width: 8),
                          _dropdownPill(
                            label: _zoneLabel(),
                            onTap: _zonesLoading
                                ? () {}
                                : () => _openZoneSheet(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Bottom border
                  Container(height: 0.5, color: _P.s200),
                ],
              ),
            ),
            // ── List body ──
            Expanded(
              child: _isLoading && _customers.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                        strokeWidth: 2,
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF7C3AED),
                      onRefresh: _refresh,
                      child: filtered.isEmpty
                          ? LottieEmptyState(
                              message: _query.isEmpty
                                  ? 'No customers found'
                                  : 'No results for "$_query"',
                              lottieAsset: _query.isEmpty
                                  ? 'assets/lottie/empty_state.json'
                                  : 'assets/lottie/search_empty.json',
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              cacheExtent: 480,
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 24,
                              ),
                              itemCount:
                                  filtered.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    height: 0.5,
                                    thickness: 0.5,
                                    color: _P.s200,
                                  ),
                              itemBuilder: (context, index) {
                                if (index >= filtered.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF7C3AED),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final customer = filtered[index];
                                final rowKey = customer.id.isNotEmpty
                                    ? 'c_${customer.id}'
                                    : 'c_row_$index';
                                return RepaintBoundary(
                                  child: AnimatedListItem(
                                    index: index,
                                    child: _CustomerRow(
                                      key: ValueKey(rowKey),
                                      rowIndex: index,
                                      customer: customer,
                                      fields: _cardFields,
                                      label: _labelForCustomer(customer.id),
                                      onMoreTap: () =>
                                          _openCustomerRowMenu(customer),
                                      onTap: () async {
                                        await Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                CustomerDetailsScreen(
                                                  customerId: customer.id,
                                                  customerName: customer.name,
                                                ),
                                          ),
                                        );
                                        _loadCustomers(
                                          reset: true,
                                        ); // detail/edit se wapas aane pe list refresh
                                      },
                                      onEdit: () async {
                                        await context.push(
                                          AppRoutes.editCustomer,
                                          extra: customer,
                                        );
                                        _loadCustomers(reset: true);
                                      },
                                      onWhatsApp: () => WhatsAppHelper.openChat(
                                        customer.phone,
                                      ),
                                      onDelete: () =>
                                          _confirmDelete(context, customer),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ), // RefreshIndicator / Center
            ), // Expanded
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab_add',
        onPressed: _openAddCustomer,
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Customer row widget ──────────────────────────────────────────────────────
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    super.key,
    required this.rowIndex,
    required this.customer,
    required this.fields,
    this.label,
    required this.onMoreTap,
    required this.onTap,
    required this.onEdit,
    required this.onWhatsApp,
    required this.onDelete,
  });

  final int rowIndex;
  final CustomerModel customer;
  final Set<_CardField> fields;
  final String? label;
  final VoidCallback onMoreTap;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onWhatsApp;
  final VoidCallback onDelete;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(customer.name);
    final avatarColor = colorFromName(customer.name);
    final accent = _accentColor(customer.status);
    final hasArea = customer.area?.isNotEmpty == true;
    final balanceShown = customer.effectiveSubscriptionBalance;
    final isLowBal = balanceShown < 100;
    final showName = fields.contains(_CardField.name);
    final showPhone = fields.contains(_CardField.phone);
    final showArea = fields.contains(_CardField.area);
    final showBalance = fields.contains(_CardField.balance);

    final slideKey = customer.id.trim().isNotEmpty
        ? 'slidable_${customer.id}'
        : 'slidable_row_$rowIndex';
    return Slidable(
      key: ValueKey(slideKey),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.62,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: _P.v100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.edit_outlined, color: _P.v700, size: 18),
                SizedBox(height: 3),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _P.v700,
                  ),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onWhatsApp(),
            backgroundColor: Color(0xFFDCFCE7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF166534),
                  size: 18,
                ),
                SizedBox(height: 3),
                Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: _P.redBg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.delete_outline_rounded, color: _P.redTxt, size: 18),
                SizedBox(height: 3),
                Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _P.redTxt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent bar — 3px, full height ──
              Container(width: 3, color: accent),

              // ── Row content ──
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      // Avatar with rounded square
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),

                      // Name + phone + area tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (showName)
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (showPhone) ...[
                              const SizedBox(height: 2),
                              Text(
                                customer.phone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            if (showArea && hasArea) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFDDD6FE),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  customer.area!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5B21B6),
                                  ),
                                ),
                              ),
                            ],
                            if ((label?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _P.v100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFDDD6FE),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  label!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: _P.v700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Remaining subscription balance (same source as detail info tab)
                      if (showBalance)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${balanceShown.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isLowBal
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'remaining balance',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      IconButton(
                        onPressed: onMoreTap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: _P.s400,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer menu helpers / screens (added feature)
// ─────────────────────────────────────────────────────────────────────────────

enum _CardField { name, phone, area, balance }

extension _CardFieldX on _CardField {
  String get key => switch (this) {
    _CardField.name => 'name',
    _CardField.phone => 'phone',
    _CardField.area => 'area',
    _CardField.balance => 'remaining balance',
  };

  String get label => switch (this) {
    _CardField.name => 'Name',
    _CardField.phone => 'Phone',
    _CardField.area => 'Zone/Area',
    _CardField.balance => 'Remaining Balance',
  };

  static _CardField? tryParse(String raw) {
    switch (raw) {
      case 'name':
        return _CardField.name;
      case 'phone':
        return _CardField.phone;
      case 'area':
        return _CardField.area;
      case 'balance':
        return _CardField.balance;
      default:
        return null;
    }
  }
}

final class _CustomerAnalyticsScreen extends StatelessWidget {
  const _CustomerAnalyticsScreen({required this.customers});

  final List<CustomerModel> customers;

  @override
  Widget build(BuildContext context) {
    int countWhere(bool Function(CustomerModel) test) =>
        customers.where(test).length;

    final active = countWhere((c) => (c.status).toLowerCase() == 'active');
    final paused = countWhere((c) => (c.status).toLowerCase() == 'paused');
    final blocked = countWhere((c) => (c.status).toLowerCase() == 'blocked');
    final lowBal = countWhere((c) => c.effectiveSubscriptionBalance < 100);

    final veg = countWhere(
      (c) => (c.dietType ?? '').toLowerCase().contains('veg'),
    );
    final nonVeg = countWhere((c) {
      final d = (c.dietType ?? '').toLowerCase();
      return d.contains('non') || d.contains('nv');
    });

    final zones = <String, int>{};
    for (final c in customers) {
      final z = (c.area ?? '').trim();
      if (z.isEmpty) continue;
      zones[z] = (zones[z] ?? 0) + 1;
    }
    final zoneList = zones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget card(String label, String value) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.s200, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _P.s900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _P.s600,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        title: const Text('Customer Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(child: card('Total customers', '${customers.length}')),
              const SizedBox(width: 10),
              Expanded(child: card('Low balance', '$lowBal')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: card('Active', '$active')),
              const SizedBox(width: 10),
              Expanded(child: card('Paused', '$paused')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: card('Blocked', '$blocked')),
              const SizedBox(width: 10),
              Expanded(child: card('Veg / Non-Veg', '$veg / $nonVeg')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Zone wise distribution',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _P.s600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          if (zoneList.isEmpty)
            const Text(
              'No zones available',
              style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
            )
          else
            ...zoneList
                .take(12)
                .map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _P.s200, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _P.s900,
                            ),
                          ),
                        ),
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _P.v700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

final class _ArchivedCustomersScreen extends StatelessWidget {
  const _ArchivedCustomersScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        title: const Text('Archived Customers'),
      ),
      body: const Center(
        child: Text(
          'No archived customers yet',
          style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

final class _ImportCustomersScreen extends StatefulWidget {
  const _ImportCustomersScreen({required this.onImported});

  final void Function(List<CustomerModel>) onImported;

  @override
  State<_ImportCustomersScreen> createState() => _ImportCustomersScreenState();
}

final class _ImportCustomersScreenState extends State<_ImportCustomersScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _preview = const [];
  bool _importing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> _parseCsv(String csv) {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    List<String> splitLine(String line) {
      final out = <String>[];
      final buf = StringBuffer();
      var inQuotes = false;
      for (var i = 0; i < line.length; i += 1) {
        final ch = line[i];
        if (ch == '"') {
          inQuotes = !inQuotes;
          continue;
        }
        if (ch == ',' && !inQuotes) {
          out.add(buf.toString().trim());
          buf.clear();
          continue;
        }
        buf.write(ch);
      }
      out.add(buf.toString().trim());
      return out;
    }

    final headers = splitLine(lines.first).map((e) => e.toLowerCase()).toList();
    final rows = <Map<String, String>>[];
    for (final l in lines.skip(1)) {
      final cells = splitLine(l);
      final m = <String, String>{};
      for (var i = 0; i < headers.length && i < cells.length; i += 1) {
        m[headers[i]] = cells[i];
      }
      rows.add(m);
    }
    return rows;
  }

  void _updatePreview() {
    setState(() => _preview = _parseCsv(_ctrl.text));
  }

  Future<void> _import() async {
    if (_preview.isEmpty || _importing) return;
    setState(() => _importing = true);
    try {
      final result = await CustomerApi.bulkImportCsv(_ctrl.text.trim());
      final rawCustomers = result['customers'];
      final items = <CustomerModel>[];
      if (rawCustomers is List) {
        for (final e in rawCustomers) {
          if (e is CustomerModel) items.add(e);
        }
      }
      final imported = (result['imported'] as int?) ?? 0;
      final skipped = (result['skipped'] as int?) ?? 0;
      final warnings = result['warnings'];
      if (!mounted) return;
      widget.onImported(items);
      var msg = 'Imported $imported customer${imported == 1 ? '' : 's'}';
      if (skipped > 0) msg += ' ($skipped skipped)';
      if (warnings is List && warnings.isNotEmpty) {
        msg +=
            '. ${warnings.length} zone name(s) did not match — customers were added without a zone.';
      }
      AppSnackbar.success(context, msg);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        title: const Text('Import Bulk Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Paste CSV data',
            style: TextStyle(fontWeight: FontWeight.w800, color: _P.s900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  'name,phone,address,zone\nJohn,9876543210,Street 1,Zone A',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => _updatePreview(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Preview',
            style: TextStyle(fontWeight: FontWeight.w800, color: _P.s900),
          ),
          const SizedBox(height: 8),
          if (_preview.isEmpty)
            const Text(
              'No rows found',
              style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
            )
          else
            ..._preview
                .take(8)
                .map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _P.s200, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (r['name'] ?? '').isEmpty
                              ? '(missing name)'
                              : r['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _P.s900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (r['phone'] ?? r['mobile'] ?? '').toString(),
                          style: const TextStyle(color: _P.s600),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_preview.isEmpty || _importing) ? null : _import,
            style: FilledButton.styleFrom(
              backgroundColor: _P.g1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _importing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm Import',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}

final class _TiffinsOutsideScreen extends StatelessWidget {
  const _TiffinsOutsideScreen({required this.customers, required this.total});

  final List<CustomerModel> customers;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        title: const Text('Total Tiffins Outside'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.s200, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: _P.v700),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Total outside',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _P.s900,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _P.v700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (customers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  'No tiffins outside right now',
                  style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...customers.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _P.s200, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _P.s900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.area ?? '',
                            style: const TextStyle(color: _P.s600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${c.tiffinCount ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _P.v700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
