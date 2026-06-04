import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../models/customer_model.dart';
import '../../../delivery/models/delivery_staff_model.dart';
import '../../../items/models/item_model.dart';
import '../../../orders/models/order_model.dart';
import '../../../payments/models/invoice_model.dart';
import '../../../payments/models/payment_model.dart';
import '../../../plans/models/plan_model.dart';
import '../../../subscriptions/models/subscription_model.dart';
import '../../data/admin_api.dart';

enum AdminListType {
  vendors,
  customers,
  deliveryStaff,
  plans,
  items,
  subscriptions,
  orders,
  payments,
  invoices,
}

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key, required this.type});

  final AdminListType type;

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      switch (widget.type) {
        case AdminListType.vendors:
          final list = await AdminApi.getVendors(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.customers:
          final list = await AdminApi.getCustomers(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.deliveryStaff:
          final list = await AdminApi.getDeliveryStaff(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.plans:
          final list = await AdminApi.getPlans(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.items:
          final list = await AdminApi.getItems(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.subscriptions:
          final list = await AdminApi.getSubscriptions(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.orders:
          final list = await AdminApi.getOrders(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.payments:
          final list = await AdminApi.getPayments(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
        case AdminListType.invoices:
          final list = await AdminApi.getInvoices(limit: 100);
          if (mounted) setState(() => _items = list);
          break;
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _title {
    switch (widget.type) {
      case AdminListType.vendors:
        return 'Vendors';
      case AdminListType.customers:
        return 'Customers';
      case AdminListType.deliveryStaff:
        return 'Delivery staff';
      case AdminListType.plans:
        return 'Plans';
      case AdminListType.items:
        return 'Items';
      case AdminListType.subscriptions:
        return 'Plan assignments';
      case AdminListType.orders:
        return 'Orders';
      case AdminListType.payments:
        return 'Payments';
      case AdminListType.invoices:
        return 'Invoices';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppColors.onSurface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(context).padding.bottom + 24,
                      ),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.35,
                        ),
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'No records yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'When data exists for this category, it will appear here. Pull down to refresh.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(context).padding.bottom + 16,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              _itemTitle(item),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: _itemSubtitle(item) != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _itemSubtitle(item)!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _itemTitle(dynamic item) {
    if (item is CustomerModel) return '${item.name} (${item.phone})';
    if (item is DeliveryStaffModel) return '${item.name} (${item.phone})';
    if (item is PlanModel) return '${item.planName} • ₹${item.price.toStringAsFixed(0)}';
    if (item is ItemModel) {
      return '${item.name} • ${item.unit}';
    }
    if (item is SubscriptionModel) {
      return '${item.customerName ?? item.customerId} • ${item.planName ?? item.planId}';
    }
    if (item is OrderModel) {
      return '${item.customerName ?? item.customerId} • ${item.status}';
    }
    if (item is PaymentModel) {
      return '${item.customerName ?? item.customerId} • ₹${item.amount.toStringAsFixed(0)}';
    }
    if (item is InvoiceModel) {
      return '${item.customerName ?? item.customerId} • ₹${item.amount.toStringAsFixed(0)}';
    }
    if (item is Map<String, dynamic>) {
      final business = item['businessName']?.toString().trim();
      if (business != null && business.isNotEmpty) return business;
      final owner = item['ownerName']?.toString().trim();
      if (owner != null && owner.isNotEmpty) return owner;
      final name = item['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      return item['_id']?.toString() ?? '—';
    }
    return '—';
  }

  String? _itemSubtitle(dynamic item) {
    if (item is OrderModel) return '${item.date.day}/${item.date.month}/${item.date.year} • ${item.slot}';
    if (item is PaymentModel) return item.paymentMethod;
    if (item is InvoiceModel) return item.status;
    if (item is SubscriptionModel) return '${item.status} • ${item.deliverySlot}';
    if (item is Map<String, dynamic>) {
      final parts = <String>[];
      final phone = item['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) parts.add(phone);
      final email = item['email']?.toString().trim();
      if (email != null && email.isNotEmpty) parts.add(email);
      final owner = item['ownerName']?.toString().trim();
      final business = item['businessName']?.toString().trim();
      if (owner != null &&
          owner.isNotEmpty &&
          business != null &&
          business.isNotEmpty &&
          owner != business) {
        parts.insert(0, owner);
      }
      final city = item['city']?.toString().trim();
      if (city != null && city.isNotEmpty) parts.add(city);
      final active = item['isActive'];
      if (active is bool) {
        parts.add(active ? 'Active' : 'Inactive');
      }
      return parts.isEmpty ? null : parts.join(' · ');
    }
    return null;
  }
}
