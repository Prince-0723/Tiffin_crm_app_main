abstract final class ApiEndpoints {
  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';
  static const String authMe = '/auth/me';

  /// Dedicated FCM token sync (also supported via PUT /auth/me).
  static const String usersFcmToken = '/users/fcm-token';

  /// Vendor portal announcement (GET/PUT).
  static const String usersPortalAnnouncement = '/users/portal-announcement';

  /// Monthly finance overview (vendor).
  static const String vendorFinanceMonthly = '/vendor/finance/monthly';

  /// Aggregated menu items to prepare for a day (vendor dashboard).
  static const String vendorDashboardDailyItems = '/vendor/dashboard/daily-items';
  static const String vendorOnboarding = '/auth/vendor/onboarding';
  static const String changePassword = '/auth/change-password';
  static String subscriptionUpdate(String id) => '/subscriptions/$id'; // ✅ ADD
  // Customers (vendor/admin)
  static const String customers = '/customers';
  static String customerById(String id) => '/customers/$id';
  static const String customersBulk = '/customers/bulk';
  static String customerWalletCredit(String id) =>
      '/customers/$id/wallet/credit';
  static String customerPlans(String id) => '/customers/$id/plans';

  /// Vendor-only: tiffin box count + ledger (see `CustomerTiffinApi`).
  static String vendorCustomerTiffin(String customerId) =>
      '/vendor/customers/$customerId/tiffin';
  static String vendorCustomerTiffinIncrement(String customerId) =>
      '/vendor/customers/$customerId/tiffin/increment';
  static String vendorCustomerTiffinDecrement(String customerId) =>
      '/vendor/customers/$customerId/tiffin/decrement';

  // Customer portal (self-service)
  static const String customerMe = '/customer/me';
  /// Public (no auth): vendor portal announcement — `ownerId` is vendor User id.
  static String publicVendorPortalAnnouncement(String ownerId) =>
      '/public/vendor/$ownerId/portal-announcement';
  static const String customerMeBalance = '/customer/me/balance';
  static const String customerMePlan = '/customer/me/plan';
  static const String customerMeOrders = '/customer/me/orders';
  static const String customerMeNotifications = '/customer/me/notifications';
  static String customerMeNotificationMarkRead(String id) =>
      '/customer/me/notifications/$id/read';

  // Notifications (vendor / delivery_staff / admin)
  static const String notifications = '/notifications';
  static String notificationMarkRead(String id) => '/notifications/$id/read';
  static String notificationById(String id) => '/notifications/$id';
  static const String notificationsClearRead = '/notifications/clear-read';

  // Customer portal notifications extra endpoints
  static String customerMeNotificationById(String id) =>
      '/customer/me/notifications/$id';
  static const String customerMeNotificationsClearRead =
      '/customer/me/notifications/clear-read';

  // Items
  static const String items = '/items';
  static String itemById(String id) => '/items/$id';

  // Delivery staff
  static const String deliveryStaff = '/delivery-staff';
  static const String deliveryStaffMe = '/delivery-staff/me';
  static String deliveryStaffById(String id) => '/delivery-staff/$id';

  // Zones
  static const String zones = '/zones';
  static String zoneById(String id) => '/zones/$id';

  // Plans
  static const String plans = '/plans';
  static String planById(String id) => '/plans/$id';

  // Subscriptions
  static const String subscriptions = '/subscriptions';
  static String subscriptionById(String id) => '/subscriptions/$id';
  static String subscriptionRenew(String id) => '/subscriptions/$id/renew';
  static String subscriptionCancel(String id) => '/subscriptions/$id/cancel';
  static String subscriptionPause(String id) => '/subscriptions/$id/pause';
  static String subscriptionUnpause(String id) => '/subscriptions/$id/unpause';

  // Daily orders
  static const String dailyOrdersToday = '/daily-orders/today';
  static const String dailyOrdersProcess = '/daily-orders/process';
  static const String dailyOrdersCancelVendorHoliday =
      '/daily-orders/cancel-vendor-holiday';
  static const String dailyOrdersMarkDelivered = '/daily-orders/mark-delivered';
  static const String dailyOrdersAssignBulk = '/daily-orders/assign-bulk';
  static const String dailyOrdersBulkStatus = '/daily-orders/bulk-status';
  static const String dailyOrdersGenerate = '/daily-orders/generate';
  static const String dailyOrdersGenerateWeek = '/daily-orders/generate-week';
  static String dailyOrderAssign(String id) => '/daily-orders/$id/assign';
  static String dailyOrderStatus(String id) => '/daily-orders/$id/status';
  static String dailyOrderQuantities(String id) =>
      '/daily-orders/$id/quantities';
  static String dailyOrderAccept(String id) => '/daily-orders/$id/accept';
  static String dailyOrderReject(String id) => '/daily-orders/$id/reject';

  // Delivery (staff view)
  static const String delivery = '/delivery';
  static const String deliveryMyDeliveries = '/delivery/my-deliveries';

  // Payments
  static const String payments = '/payments';
  static const String paymentsCreateOrder = '/payments/create-order';
  static String paymentInvoice(String id) => '/payments/$id/invoice';

  // Invoices
  static const String invoices = '/invoices';
  static const String invoicesGenerate = '/invoices/generate';
  static const String invoicesOverdue = '/invoices/overdue';
  static String invoiceById(String id) => '/invoices/$id';
  static String invoiceShare(String id) => '/invoices/$id/share';
  static String invoiceVoid(String id) => '/invoices/$id/void';
  static const String invoicesDaily = '/invoices/daily';

  // Expenses
  static const String expenses = '/expenses';
  static const String expensesSummary = '/expenses/summary';
  static String expenseById(String id) => '/expenses/$id';

  // Income
  static const String incomes = '/incomes';
  static String incomeById(String id) => '/incomes/$id';

  // Reports
  static const String reportsSummary = '/reports/summary';
  static const String reportsTodayDeliveries = '/reports/today-deliveries';
  static const String reportsExpiringSubscriptions =
      '/reports/expiring-subscriptions';
  static const String reportsPendingPayments = '/reports/pending-payments';

  // Admin
  static const String adminStats = '/admin/stats';
  static const String adminVendorsStats = '/admin/vendors/stats';
  static const String adminVendors = '/admin/vendors';
  static const String adminCustomers = '/admin/customers';
  static const String adminDeliveryStaff = '/admin/delivery-staff';
  static const String adminPlans = '/admin/plans';
  static const String adminItems = '/admin/items';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminOrders = '/admin/orders';
  static const String adminPayments = '/admin/payments';
  static const String adminInvoices = '/admin/invoices';
  static const String adminNotifications = '/admin/notifications';
}
