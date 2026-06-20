// // ignore_for_file: unused_field

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../auth/auth_session.dart';
// import '../router/app_routes.dart';
// import '../utils/app_snackbar.dart';
// import 'notification_bell_icon.dart';
// import 'drawer_storefront_icon.dart';
// import '../theme/theme_mode_provider.dart';
// import '../../features/auth/data/auth_api.dart';
// import '../../features/profile/data/profile_api.dart';
// import '../../features/support/screens/support_screen.dart';
// import '../../features/support/screens/learn_more_screen.dart';
// import '../../features/portal/presentation/screens/portal_announcement_screen.dart';
// import '../../features/expenses/screens/expenses_screen.dart';
// import '../../features/income/screens/income_screen.dart';
// import '../../features/dashboard/presentation/screens/monthly_finance_screen.dart';
// import '../../screens/finance/finance_screen.dart';

// class AppDrawer extends ConsumerStatefulWidget {
//   const AppDrawer({super.key, this.fallbackUserName = 'Guest'});
//   final String fallbackUserName;

//   @override
//   ConsumerState<AppDrawer> createState() => _AppDrawerState();
// }

// class _AppDrawerState extends ConsumerState<AppDrawer> {
//   // ── Violet palette (matches PaymentsScreen) ───────────────────────────────
//   static const _violet700 = Color(0xFF4C2DB8);
//   // ignore: duplicate_ignore
//   // ignore: unused_field
//   static const _violet600 = Color(0xFF5B35D5);
//   // ignore: duplicate_ignore
//   // ignore: unused_field
//   static const _violet100 = Color(0xFFEDE8FD);
//   // ignore: duplicate_ignore
//   // ignore: unused_field
//   static const _violet50 = Color(0xFFF5F2FF);
//   static const _bg = Color(0xFFF6F4FF);
//   static const _border = Color(0xFFE4DFF7);
//   static const _dividerColor = Color(0xFFEEEBFA);
//   static const _textPrimary = Color(0xFF1A0E45);
//   static const _textSecondary = Color(0xFF7B6DAB);
//   static const _danger = Color(0xFFD93025);
//   static const _dangerSoft = Color(0xFFFCECEB);

//   // ── State ─────────────────────────────────────────────────────────────────
//   String _businessName = '';
//   String _ownerName = '';
//   bool _profileLoaded = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile();
//   }

//   Future<void> _loadProfile() async {
//     try {
//       final data = await ProfileApi.getMe();
//       if (mounted) {
//         setState(() {
//           _businessName =
//               data['businessName'] as String? ??
//               data['tiffinCenterName'] as String? ??
//               '';
//           _ownerName =
//               data['name'] as String? ??
//               data['ownerName'] as String? ??
//               widget.fallbackUserName;
//           _profileLoaded = true;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _profileLoaded = true);
//     }
//   }

//   void _close() => Navigator.of(context).pop();
//   void _go(String route) {
//     _close();
//     context.push(route);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final displayName = _businessName.isNotEmpty
//         ? _businessName
//         : (_ownerName.isNotEmpty ? _ownerName : widget.fallbackUserName);

//     return Container(
//       width: MediaQuery.of(context).size.width * 0.82,
//       color: _bg,
//       child: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             _buildHeader(displayName),
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.only(
//                   top: 6,
//                   bottom: MediaQuery.of(context).padding.bottom + 24,
//                 ),
//                 children: [
//                   // ── Main ──────────────────────────────────────────────────
//                   _label('Main'),
//                   _Item(
//                     icon: Icons.person_outline_rounded,
//                     label: 'Profile Info',
//                     onTap: () {
//                       _close();
//                       context
//                           .push(AppRoutes.profile)
//                           .then((_) => _loadProfile());
//                     },
//                   ),
//                   _Item(
//                     icon: Icons.notifications_outlined,
//                     label: 'Notifications',
//                     customLeading: const NotificationBellIcon(
//                       onPressed: null,
//                       size: 20,
//                     ),
//                     onTap: () => _go(AppRoutes.notifications),
//                   ),
//                   _Item(
//                     icon: Icons.login_rounded,
//                     label: 'My Meals',
//                     onTap: () {
//                       _close();
//                       context.push(
//                         AppRoutes.login,
//                         extra: const <String, dynamic>{'selectedRole': 'customer'},
//                       );
//                     },
//                   ),

//                   _Divider(color: _dividerColor),

//                   // ── Operations ────────────────────────────────────────────
//                   _label('Operations'),
//                   _Item(
//                     icon: Icons.receipt_long_outlined,
//                     label: 'Daily Orders',
//                     onTap: () => _go(AppRoutes.delivery),
//                   ),
//                   _Item(
//                     icon: Icons.groups_outlined,
//                     label: 'Delivery Staff',
//                     onTap: () => _go(AppRoutes.deliveryStaff),
//                   ),
//                   _Item(
//                     icon: Icons.map_outlined,
//                     label: 'Delivery Zones',
//                     onTap: () => _go(AppRoutes.zones),
//                   ),
//                   _Item(
//                     icon: Icons.restaurant_menu_rounded,
//                     label: 'Menu Items',
//                     onTap: () => _go(AppRoutes.items),
//                   ),
//                   _Item(
//                     icon: Icons.edit_note_rounded,
//                     label: 'Standard Meal Plans',
//                     onTap: () => _go(AppRoutes.mealPlans),
//                   ),

//                   _Divider(color: _dividerColor),

//                   _label('Finance'),
//                   _Item(
//                     icon: Icons.bar_chart_rounded,
//                     label: 'Overview',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute<void>(
//                           builder: (_) => const FinanceScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                   _Item(
//                     icon: Icons.add_circle_outline_rounded,
//                     label: 'Add Income',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute<void>(
//                           builder: (_) => const IncomeScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                   _Item(
//                     icon: Icons.remove_circle_outline_rounded,
//                     label: 'Add Expense',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute<void>(
//                           builder: (_) => const ExpensesScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                   _Item(
//                     icon: Icons.calendar_month_outlined,
//                     label: 'Monthly View',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute<void>(
//                           builder: (_) => const MonthlyFinanceScreen(),
//                         ),
//                       );
//                     },
//                   ),

//                   _Divider(color: _dividerColor),

//                   _label('Announcement Portal'),
//                   _Item(
//                     icon: Icons.campaign_rounded,
//                     label: 'Portal Announcement',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute<void>(
//                           builder: (_) => const PortalAnnouncementScreen(),
//                         ),
//                       );
//                     },
//                   ),

//                   _Divider(color: _dividerColor),

//                   // ── Settings & Support ────────────────────────────────────
//                   _label('Settings & Support'),
//                   _Item(
//                     icon: Icons.settings_outlined,
//                     label: 'Settings',
//                     onTap: () => _go(AppRoutes.settings),
//                   ),
//                   _ThemeModeTile(
//                     icon: Icons.dark_mode_outlined,
//                     label: 'Dark Mode',
//                     value: ref.watch(themeModeProvider) == ThemeMode.dark,
//                     onChanged: () => ref.read(themeModeProvider.notifier).toggle(),
//                   ),

//                   // ── ROUTE FIXED: Learn More ───────────────────────────────
//                   _Item(
//                     icon: Icons.info_outline_rounded,
//                     label: 'Learn More',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (_) => const LearnMoreScreen(),
//                         ),
//                       );
//                     },
//                   ),

//                   _Item(
//                     icon: Icons.share_outlined,
//                     label: 'Share TiffinCRM App',
//                     onTap: () {
//                       _close();
//                       AppSnackbar.success(context, 'Share TiffinCRM App');
//                     },
//                   ),
//                   _Item(
//                     icon: Icons.star_outline_rounded,
//                     label: 'Rate This App!',
//                     onTap: () {
//                       _close();
//                       AppSnackbar.success(context, 'Rate This App!');
//                     },
//                   ),

//                   // ── ROUTE FIXED: Support ──────────────────────────────────
//                   _Item(
//                     icon: Icons.headset_mic_outlined,
//                     label: 'Support',
//                     onTap: () {
//                       _close();
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (_) => const SupportScreen(),
//                         ),
//                       );
//                     },
//                   ),

//                   _Divider(color: _dividerColor),

//                   // ── Logout ────────────────────────────────────────────────
//                   _LogoutTile(
//                     danger: _danger,
//                     dangerSoft: _dangerSoft,
//                     onTap: () async {
//                       _close();
//                       await AuthApi.logout();
//                       await AuthSession.clearLocalSession();
//                       if (context.mounted) context.go(AppRoutes.login);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Header ────────────────────────────────────────────────────────────────
//   Widget _buildHeader(String displayName) => Container(
//     color: _violet700,
//     padding: const EdgeInsets.fromLTRB(16, 20, 14, 16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             GestureDetector(
//               onTap: () {
//                 _close();
//                 context.push(AppRoutes.profile).then((_) => _loadProfile());
//               },
//               child: DrawerStorefrontIcon(
//                 size: 44,
//                 headerBackgroundColor: _violet700,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: GestureDetector(
//                 onTap: () {
//                   _close();
//                   context.push(AppRoutes.profile).then((_) => _loadProfile());
//                 },
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     !_profileLoaded
//                         ? Container(
//                             height: 14,
//                             width: 100,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withValues(alpha: 0.2),
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                           )
//                         : Text(
//                             displayName,
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                               letterSpacing: 0.1,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                     const SizedBox(height: 3),
//                     Text(
//                       _ownerName.isNotEmpty
//                           ? _ownerName
//                           : 'Tap to complete profile',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.white.withValues(alpha: 0.72),
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             GestureDetector(
//               onTap: _close,
//               child: Container(
//                 width: 34,
//                 height: 34,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.14),
//                   borderRadius: BorderRadius.circular(9),
//                   border: Border.all(
//                     color: Colors.white.withValues(alpha: 0.2),
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.close_rounded,
//                   size: 17,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         GestureDetector(
//           onTap: () {
//             _close();
//             context.push(AppRoutes.profile).then((_) => _loadProfile());
//           },
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//             decoration: BoxDecoration(
//               color: Colors.white.withValues(alpha: 0.11),
//               borderRadius: BorderRadius.circular(9),
//               border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.edit_outlined,
//                   size: 13,
//                   color: Colors.white.withValues(alpha: 0.85),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Edit Profile & Business Info',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.white.withValues(alpha: 0.9),
//                   ),
//                 ),
//                 const Spacer(),
//                 Icon(
//                   Icons.chevron_right_rounded,
//                   size: 15,
//                   color: Colors.white.withValues(alpha: 0.65),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     ),
//   );

//   Widget _label(String text) => Padding(
//     padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
//     child: Text(
//       text.toUpperCase(),
//       style: const TextStyle(
//         fontSize: 10,
//         fontWeight: FontWeight.w700,
//         color: _textSecondary,
//         letterSpacing: 1.2,
//       ),
//     ),
//   );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // _Item
// // ─────────────────────────────────────────────────────────────────────────────

// class _Item extends StatelessWidget {
//   const _Item({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//     this.customLeading,
//   });

//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//   final Widget? customLeading;

//   static const _violet600 = Color(0xFF5B35D5);
//   static const _violet50 = Color(0xFFF5F2FF);
//   static const _violet100 = Color(0xFFEDE8FD);
//   static const _border = Color(0xFFE4DFF7);
//   static const _textPrimary = Color(0xFF1A0E45);
//   static const _textSecondary = Color(0xFF7B6DAB);

//   @override
//   Widget build(BuildContext context) => InkWell(
//     onTap: onTap,
//     splashColor: _violet100,
//     highlightColor: _violet50,
//     child: Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 5),
//         child: Row(
//           children: [
//             Container(
//               width: 34,
//               height: 34,
//               decoration: BoxDecoration(
//                 color: _violet50,
//                 borderRadius: BorderRadius.circular(9),
//                 border: Border.all(color: _border),
//               ),
//               child: customLeading != null
//                   ? Center(child: customLeading)
//                   : Icon(icon, size: 17, color: _violet600),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   color: _textPrimary,
//                 ),
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             Icon(
//               Icons.chevron_right_rounded,
//               size: 15,
//               color: _textSecondary.withValues(alpha: 0.4),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// class _ThemeModeTile extends StatelessWidget {
//   const _ThemeModeTile({
//     required this.icon,
//     required this.label,
//     required this.value,
//     required this.onChanged,
//   });

//   final IconData icon;
//   final String label;
//   final bool value;
//   final VoidCallback onChanged;

//   static const _violet600 = Color(0xFF5B35D5);
//   static const _violet50 = Color(0xFFF5F2FF);
//   static const _violet100 = Color(0xFFEDE8FD);
//   static const _border = Color(0xFFE4DFF7);
//   static const _textPrimary = Color(0xFF1A0E45);

//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
//     child: Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         children: [
//           Container(
//             width: 34,
//             height: 34,
//             decoration: BoxDecoration(
//               color: _violet50,
//               borderRadius: BorderRadius.circular(9),
//               border: Border.all(color: _border),
//             ),
//             child: Icon(icon, size: 17, color: _violet600),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: _textPrimary,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           Switch.adaptive(
//             value: value,
//             activeColor: _violet600,
//             onChanged: (_) => onChanged(),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // _LogoutTile
// // ─────────────────────────────────────────────────────────────────────────────

// class _LogoutTile extends StatelessWidget {
//   const _LogoutTile({
//     required this.danger,
//     required this.dangerSoft,
//     required this.onTap,
//   });

//   final Color danger, dangerSoft;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
//     child: InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
//         decoration: BoxDecoration(
//           color: dangerSoft,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: danger.withValues(alpha: 0.22)),
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 34,
//               height: 34,
//               decoration: BoxDecoration(
//                 color: danger.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               child: Icon(Icons.logout_rounded, size: 17, color: danger),
//             ),
//             const SizedBox(width: 12),
//             Text(
//               'Logout',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 color: danger,
//               ),
//             ),
//             const Spacer(),
//             Icon(
//               Icons.chevron_right_rounded,
//               size: 15,
//               color: danger.withValues(alpha: 0.45),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // _Divider
// // ─────────────────────────────────────────────────────────────────────────────

// class _Divider extends StatelessWidget {
//   const _Divider({required this.color});
//   final Color color;

//   @override
//   Widget build(BuildContext context) => Divider(
//     color: color,
//     height: 20,
//     thickness: 1,
//     indent: 16,
//     endIndent: 16,
//   );
// }
// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_session.dart';
import '../router/app_routes.dart';
import '../utils/app_snackbar.dart';
import 'notification_bell_icon.dart';
import 'drawer_storefront_icon.dart';
import '../theme/theme_mode_provider.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/profile/data/profile_api.dart';
import '../../features/support/screens/support_screen.dart';
import '../../features/support/screens/learn_more_screen.dart';
import '../../features/portal/presentation/screens/portal_announcement_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/income/screens/income_screen.dart';
import '../../features/dashboard/presentation/screens/monthly_finance_screen.dart';
import '../../screens/finance/finance_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme-aware color helpers (extension on BuildContext)
// ─────────────────────────────────────────────────────────────────────────────

extension _DrawerColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get drawerBg =>
      _isDark ? const Color(0xFF141625) : const Color(0xFFF6F4FF);
  Color get headerBg => const Color(0xFF4C2DB8); // same in both modes

  // Item icon container
  Color get iconContainerBg =>
      _isDark ? const Color(0xFF1E1B3A) : const Color(0xFFF5F2FF);
  Color get iconContainerBorder =>
      _isDark ? const Color(0xFF2F2A55) : const Color(0xFFE4DFF7);
  Color get iconColor =>
      _isDark ? const Color(0xFF9B6AF0) : const Color(0xFF5B35D5);

  // Text
  Color get textPrimary =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1A0E45);
  Color get textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF7B6DAB);

  // Divider
  Color get dividerColor =>
      _isDark ? const Color(0xFF1E1B3A) : const Color(0xFFEEEBFA);

  // Ink / splash
  Color get splashColor =>
      _isDark ? const Color(0xFF2D2560) : const Color(0xFFEDE8FD);
  Color get highlightColor =>
      _isDark ? const Color(0xFF1E1B3A) : const Color(0xFFF5F2FF);

  // Logout
  Color get danger => const Color(0xFFD93025);
  Color get dangerSoft =>
      _isDark ? const Color(0xFF2A1210) : const Color(0xFFFCECEB);

  // Section label
  Color get sectionLabelColor =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF7B6DAB);

  // Chevron
  Color get chevronColor =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF7B6DAB);
}

// ─────────────────────────────────────────────────────────────────────────────
// AppDrawer
// ─────────────────────────────────────────────────────────────────────────────

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, this.fallbackUserName = 'Guest'});
  final String fallbackUserName;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  String _businessName = '';
  String _ownerName = '';
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ProfileApi.getMe();
      if (mounted) {
        setState(() {
          _businessName =
              data['businessName'] as String? ??
              data['tiffinCenterName'] as String? ??
              '';
          _ownerName =
              data['name'] as String? ??
              data['ownerName'] as String? ??
              widget.fallbackUserName;
          _profileLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  void _close() => Navigator.of(context).pop();
  void _go(String route) {
    _close();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _businessName.isNotEmpty
        ? _businessName
        : (_ownerName.isNotEmpty ? _ownerName : widget.fallbackUserName);

    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      color: context.drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, displayName),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  top: 6,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                children: [
                  // ── Main ──────────────────────────────────────────────────
                  _label(context, 'Main'),
                  _Item(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile Info',
                    onTap: () {
                      _close();
                      context
                          .push(AppRoutes.profile)
                          .then((_) => _loadProfile());
                    },
                  ),
                  _Item(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    customLeading: const NotificationBellIcon(
                      onPressed: null,
                      size: 20,
                    ),
                    onTap: () => _go(AppRoutes.notifications),
                  ),
                  _Item(
                    icon: Icons.login_rounded,
                    label: 'My Meals',
                    onTap: () {
                      _close();
                      context.push(
                        AppRoutes.login,
                        extra: const <String, dynamic>{'selectedRole': 'customer'},
                      );
                    },
                  ),

                  _Divider(color: context.dividerColor),

                  // ── Operations ────────────────────────────────────────────
                  _label(context, 'Operations'),
                  _Item(
                    icon: Icons.receipt_long_outlined,
                    label: 'Daily Orders',
                    onTap: () => _go(AppRoutes.delivery),
                  ),
                  _Item(
                    icon: Icons.groups_outlined,
                    label: 'Delivery Staff',
                    onTap: () => _go(AppRoutes.deliveryStaff),
                  ),
                  _Item(
                    icon: Icons.map_outlined,
                    label: 'Delivery Zones',
                    onTap: () => _go(AppRoutes.zones),
                  ),
                  _Item(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Menu Items',
                    onTap: () => _go(AppRoutes.items),
                  ),
                  _Item(
                    icon: Icons.edit_note_rounded,
                    label: 'Standard Meal Plans',
                    onTap: () => _go(AppRoutes.mealPlans),
                  ),

                  _Divider(color: context.dividerColor),

                  _label(context, 'Finance'),
                  _Item(
                    icon: Icons.bar_chart_rounded,
                    label: 'Overview',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FinanceScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Add Income',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const IncomeScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Add Expense',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExpensesScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.calendar_month_outlined,
                    label: 'Monthly View',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MonthlyFinanceScreen(),
                        ),
                      );
                    },
                  ),

                  _Divider(color: context.dividerColor),

                  _label(context, 'Announcement Portal'),
                  _Item(
                    icon: Icons.campaign_rounded,
                    label: 'Portal Announcement',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PortalAnnouncementScreen(),
                        ),
                      );
                    },
                  ),

                  _Divider(color: context.dividerColor),

                  // ── Settings & Support ────────────────────────────────────
                  _label(context, 'Settings & Support'),
                  _Item(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _go(AppRoutes.settings),
                  ),
                  _ThemeModeTile(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                    onChanged: () => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                  _Item(
                    icon: Icons.info_outline_rounded,
                    label: 'Learn More',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LearnMoreScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.share_outlined,
                    label: 'Share TiffinCRM App',
                    onTap: () {
                      _close();
                      AppSnackbar.success(context, 'Share TiffinCRM App');
                    },
                  ),
                  _Item(
                    icon: Icons.star_outline_rounded,
                    label: 'Rate This App!',
                    onTap: () {
                      _close();
                      AppSnackbar.success(context, 'Rate This App!');
                    },
                  ),
                  _Item(
                    icon: Icons.headset_mic_outlined,
                    label: 'Support',
                    onTap: () {
                      _close();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),

                  _Divider(color: context.dividerColor),

                  // ── Logout ────────────────────────────────────────────────
                  _LogoutTile(
                    danger: context.danger,
                    dangerSoft: context.dangerSoft,
                    onTap: () async {
                      _close();
                      await AuthApi.logout();
                      await AuthSession.clearLocalSession();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String displayName) => Container(
    color: context.headerBg,
    padding: const EdgeInsets.fromLTRB(16, 20, 14, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                _close();
                context.push(AppRoutes.profile).then((_) => _loadProfile());
              },
              child: DrawerStorefrontIcon(
                size: 44,
                headerBackgroundColor: context.headerBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _close();
                  context.push(AppRoutes.profile).then((_) => _loadProfile());
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    !_profileLoaded
                        ? Container(
                            height: 14,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    const SizedBox(height: 3),
                    Text(
                      _ownerName.isNotEmpty
                          ? _ownerName
                          : 'Tap to complete profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _close,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            _close();
            context.push(AppRoutes.profile).then((_) => _loadProfile());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Profile & Business Info',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: context.sectionLabelColor,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _Item  — reads theme from BuildContext
// ─────────────────────────────────────────────────────────────────────────────

class _Item extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.customLeading,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? customLeading;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    splashColor: context.splashColor,
    highlightColor: context.highlightColor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.iconContainerBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: context.iconContainerBorder),
              ),
              child: customLeading != null
                  ? Center(child: customLeading)
                  : Icon(icon, size: 17, color: context.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: context.chevronColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ThemeModeTile — reads theme from BuildContext
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeModeTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ThemeModeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.iconContainerBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: context.iconContainerBorder),
            ),
            child: Icon(icon, size: 17, color: context.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: context.iconColor,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _LogoutTile — reads theme from BuildContext
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _LogoutTile({
    required this.danger,
    required this.dangerSoft,
    required this.onTap,
  });

  final Color danger, dangerSoft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: dangerSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: danger.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.logout_rounded, size: 17, color: danger),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: danger,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: danger.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _Divider
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Divider(
    color: color,
    height: 20,
    thickness: 1,
    indent: 16,
    endIndent: 16,
  );
}