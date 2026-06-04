import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../transitions/page_transitions.dart';
import '../../features/auth/presentation/screens/facebook_login_screen.dart';
import '../../features/auth/presentation/screens/google_login_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/app_intro_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/vendor_onboarding_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/customers/presentation/screens/add_edit_customer_screen.dart';
import '../../features/customers/presentation/screens/customer_detail_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/dashboard/presentation/screens/business_profile_screen.dart';
import '../../features/dashboard/presentation/screens/delivery_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/delivery/models/delivery_staff_model.dart';
import '../../features/delivery/presentation/screens/add_edit_staff_screen.dart';
import '../../features/delivery/presentation/screens/delivery_dashboard_screen.dart';
import '../../features/delivery/presentation/screens/delivery_map_screen.dart';
import '../../features/delivery/presentation/screens/delivery_staff_list_screen.dart';
import '../../features/dashboard/presentation/screens/invoices_screen.dart';
import '../../features/dashboard/presentation/screens/maps_screen.dart';
import '../../features/dashboard/presentation/screens/meal_plans_screen.dart';
import '../../features/items/presentation/screens/items_list_screen.dart';
import '../../features/zones/presentation/screens/zones_list_screen.dart';
import '../../features/plans/models/plan_model.dart';
import '../../features/plans/presentation/screens/create_plan_screen.dart';
import '../../features/dashboard/presentation/screens/notifications_screen.dart';
import '../../features/dashboard/presentation/screens/payments_screen.dart';
import '../../features/dashboard/presentation/screens/reports_screen.dart';
import '../../features/dashboard/presentation/screens/settings_screen.dart';
import '../../features/dashboard/presentation/screens/subscriptions_screen.dart';
import '../../features/customer_portal/presentation/screens/customer_home_screen.dart';
import '../../features/customer_portal/presentation/screens/customer_notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_list_screen.dart';
import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../models/customer_model.dart';
import 'app_routes.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

final class AppRouter {
  AppRouter._();

  static bool onboardingSeen = false;

  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );
  static GlobalKey<NavigatorState> get navigatorKey => _rootKey;

  static GoRouter get router => _router;
  static final GoRouter _router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.appIntro,
    redirect: (context, state) {
      if (state.matchedLocation == AppRoutes.onboarding && AppRouter.onboardingSeen) {
        return AppRoutes.roleSelection;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.appIntro,
        name: 'appIntro',
        builder: (context, state) => const AppIntroScreen(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) {
          final extra = state.extra;
          final selectedRole = extra is Map
              ? (extra['selectedRole']?.toString() ?? 'vendor')
              : 'vendor';
          return LoginScreen(selectedRole: selectedRole);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          final extra = state.extra;
          String phone = '';
          String selectedRole = 'vendor';
          if (extra is Map) {
            phone = extra['phone']?.toString() ?? '';
            selectedRole = extra['selectedRole']?.toString() ?? 'vendor';
          } else if (extra is String) {
            phone = extra;
          }
          return OtpScreen(phone: phone, selectedRole: selectedRole);
        },
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.vendorOnboarding,
        name: 'vendorOnboarding',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return VendorOnboardingScreen(phone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) {
          final role = state.extra as String? ?? 'vendor';
          return WelcomeScreen(role: role);
        },
      ),
      GoRoute(
        path: AppRoutes.googleLogin,
        name: 'googleLogin',
        builder: (context, state) => const GoogleLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.facebookLogin,
        name: 'facebookLogin',
        builder: (context, state) => const FacebookLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerHome,
        name: 'customerHome',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerNotifications,
        name: 'customerNotifications',
        builder: (context, state) => const CustomerNotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.deliveryDashboard,
        name: 'deliveryDashboard',
        builder: (context, state) => const DeliveryDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.deliveryMap,
        name: 'deliveryMap',
        builder: (context, state) => const DeliveryMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'adminDashboard',
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: AppRoutes.adminList,
        name: 'adminList',
        builder: (context, state) {
          final type = state.extra as AdminListType?;
          if (type == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid admin list')),
            );
          }
          return AdminListScreen(type: type);
        },
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) {
          if (state.uri.path == '/' || state.uri.path.isEmpty) {
            return AppRoutes.dashboard;
          }
          return null;
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const DashboardShell()),
          ),
          GoRoute(
            path: 'customers',
            name: 'customers',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const CustomersListScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: 'add',
                name: 'addCustomer',
                pageBuilder: (context, state) =>
                    slideTransitionPage(state, const AddEditCustomerScreen()),
              ),
              GoRoute(
                path: 'detail',
                name: 'customerDetail',
                pageBuilder: (context, state) {
                  final customer = state.extra as CustomerModel?;
                  final child = customer == null
                      ? Scaffold(
                          body: Center(
                            child: Builder(
                              builder: (ctx) => Text(
                                'Customer not found',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        )
                      : CustomerDetailScreen(customer: customer);
                  return slideTransitionPage(state, child);
                },
              ),
              GoRoute(
                path: 'edit',
                name: 'editCustomer',
                pageBuilder: (context, state) {
                  final customer = state.extra as CustomerModel?;
                  final child = customer == null
                      ? Scaffold(
                          body: Center(
                            child: Builder(
                              builder: (ctx) => Text(
                                'Customer not found',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        )
                      : AddEditCustomerScreen(customer: customer);
                  return slideTransitionPage(state, child);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'items',
            name: 'items',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const ItemsListScreen()),
          ),
          GoRoute(
            path: 'meal-plans',
            name: 'mealPlans',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const MealPlansScreen()),
          ),
          GoRoute(
            path: 'create-plan',
            name: 'createPlan',
            pageBuilder: (context, state) {
              final plan = state.extra as PlanModel?;
              return slideTransitionPage(state, CreatePlanScreen(plan: plan));
            },
          ),
          GoRoute(
            path: 'subscriptions',
            name: 'subscriptions',
            pageBuilder: (context, state) {
              final plan = state.extra as PlanModel?;
              return slideTransitionPage(
                state,
                SubscriptionsScreen(initialPlan: plan),
              );
            },
          ),
          GoRoute(
            path: 'plan-assignments',
            name: 'planAssignments',
            pageBuilder: (context, state) {
              final plan = state.extra as PlanModel?;
              return slideTransitionPage(
                state,
                SubscriptionsScreen(initialPlan: plan),
              );
            },
          ),
          GoRoute(
            path: 'delivery',
            name: 'delivery',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const DeliveryScreen()),
          ),
          GoRoute(
            path: 'delivery-staff',
            name: 'deliveryStaff',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const DeliveryStaffListScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: 'add',
                name: 'addDeliveryStaff',
                pageBuilder: (context, state) =>
                    slideTransitionPage(state, const AddEditStaffScreen()),
              ),
              GoRoute(
                path: 'edit',
                name: 'editDeliveryStaff',
                pageBuilder: (context, state) {
                  final staff = state.extra as DeliveryStaffModel?;
                  return slideTransitionPage(
                    state,
                    AddEditStaffScreen(staff: staff),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'payments',
            name: 'payments',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const PaymentsScreen()),
          ),
          GoRoute(
            path: 'zones',
            name: 'zones',
            pageBuilder: (context, state) =>
                slideTransitionPage(state, const ZonesListScreen()),
          ),
          GoRoute(
            path: 'invoices',
            name: 'invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: 'reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'analytics',
            name: 'analytics',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'business-profile',
            name: 'businessProfile',
            builder: (context, state) => const BusinessProfileScreen(),
          ),
          GoRoute(
            path: 'maps',
            name: 'maps',
            builder: (context, state) =>
                MapsScreen(extra: state.extra),
          ),
          GoRoute(
            path: 'staff-management',
            name: 'staffManagement',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Staff Management'),
          ),
          GoRoute(
            path: 'recent-events',
            name: 'recentEvents',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Recent Events'),
          ),
          GoRoute(
            path: 'import-data',
            name: 'importData',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Import Data'),
          ),
          GoRoute(
            path: 'export-data',
            name: 'exportData',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Export Data'),
          ),
          GoRoute(
            path: 'learn-more',
            name: 'learnMore',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Learn More'),
          ),
          GoRoute(
            path: 'support',
            name: 'support',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Support'),
          ),
          GoRoute(
            path: 'tier-details',
            name: 'tierDetails',
            builder: (context, state) =>
                _PlaceholderScreen(routeLabel: 'Tier Details'),
          ),
        ],
      ),
    ],
  );
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.routeLabel});

  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeLabel)),
      body: Center(
        child: Text(routeLabel, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
