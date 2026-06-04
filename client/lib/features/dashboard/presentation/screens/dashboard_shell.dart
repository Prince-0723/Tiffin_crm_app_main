import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/notifications/notification_badge_service.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/models/user_model.dart';
import '../../../../screens/finance/finance_refresh_signal.dart';
import '../../../customers/presentation/screens/customers_list_screen.dart';
import 'dashboard_home_screen.dart';
import 'delivery_screen.dart';
import 'finance_shell.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, this.adminName = 'Vendor'});
  final String adminName;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _vendorDisplayName = 'Vendor';
  bool _profileLoaded = false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVendorProfile();
    NotificationBadgeService.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationBadgeService.refreshNow();
    }
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadVendorProfile() async {
    try {
      final user = await AuthApi.getProfile();
      if (mounted) {
        setState(() {
          _vendorDisplayName = _displayNameFromUser(user);
          _profileLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vendorDisplayName = widget.adminName;
          _profileLoaded = true;
        });
      }
    }
  }

  static String _displayNameFromUser(UserModel user) {
    if (user.businessName.isNotEmpty) return user.businessName;
    if (user.name.isNotEmpty) return user.name;
    return 'Vendor';
  }

  // ─── Nav items (4 tabs — no Invoice) ──────────────────────────────────────

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: PhosphorIconsRegular.house,
      iconSelected: PhosphorIconsFill.house,
      label: 'Overview',
    ),
    _NavItem(
      icon: PhosphorIconsRegular.receipt,
      iconSelected: PhosphorIconsFill.receipt,
      label: 'Orders',
    ),
    _NavItem(
      icon: PhosphorIconsRegular.users,
      iconSelected: PhosphorIconsFill.users,
      label: 'Customers',
    ),
    _NavItem(
      icon: PhosphorIconsRegular.wallet,
      iconSelected: PhosphorIconsFill.wallet,
      label: 'Finance',
    ),
  ];

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.92),
                    const Color(0xFF3B1578),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.list,
              size: 22,
              color: AppColors.onPrimary,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Scaffold.of(context).openDrawer();
            },
            tooltip: 'Open menu',
          ),
        ),
        title: Text(
          _profileLoaded ? _vendorDisplayName : 'TiffinCRM',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: const [
          _DashboardNotificationAction(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ),
      drawer: Drawer(child: AppDrawer(fallbackUserName: _vendorDisplayName)),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          RepaintBoundary(
            child: DashboardHomeScreen(adminName: _vendorDisplayName),
          ),
          const RepaintBoundary(
            child: DeliveryScreen(embeddedInShell: true),
          ),
          const RepaintBoundary(
            child: CustomersListScreen(),
          ),
          const RepaintBoundary(
            child: FinanceShell(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              HapticFeedback.lightImpact();
              if (index == 3) {
                financeDashboardTabSelectedTick.value++;
              }
              setState(() => _selectedIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            elevation: 0,
            selectedItemColor: AppColors.bottomNavSelected,
            unselectedItemColor: AppColors.bottomNavUnselected,
            selectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: _navItems
                .asMap()
                .entries
                .map(
                  (e) => BottomNavigationBarItem(
                    icon: PhosphorIcon(
                      _selectedIndex == e.key
                          ? e.value.iconSelected
                          : e.value.icon,
                      size: 22,
                    ),
                    label: e.value.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// Badge + bell only rebuild when [NotificationBadgeService.unreadCount] changes,
/// not on every vendor profile or tab update.
class _DashboardNotificationAction extends StatelessWidget {
  const _DashboardNotificationAction();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationBadgeService.unreadCount,
      builder: (context, unreadCount, _) {
        final hasUnread = unreadCount > 0;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  size: 22,
                  color: AppColors.onPrimary,
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  NotificationBadgeService.adjustBy(-unreadCount);
                  await context.push(AppRoutes.notifications);
                  NotificationBadgeService.refreshNow();
                },
              ),
              if (hasUnread)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.45),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.iconSelected,
    required this.label,
  });
  final IconData icon;
  final IconData iconSelected;
  final String label;
}
