import '../../models/customer_model.dart';
import '../../models/meal_plan_model.dart';
import '../../models/subscription_model.dart';
import '../../models/delivery_model.dart';
import '../../models/notification_model.dart';
import '../../models/report_model.dart';

final List<CustomerModel> mockCustomers = [
  CustomerModel(
    id: 'c1',
    name: 'Rajesh Kumar',
    phone: '+91 9876543210',
    email: 'rajesh.kumar@email.com',
    address: '42, Lamington Road, Grant Road East, Mumbai 400007',
    status: 'active',
  ),
  CustomerModel(
    id: 'c2',
    name: 'Priya Sharma',
    phone: '+91 9123456789',
    email: 'priya.sharma@email.com',
    address: 'Block A-12, Andheri West, Mumbai 400058',
    status: 'active',
  ),
  CustomerModel(
    id: 'c3',
    name: 'Amit Patel',
    phone: '+91 9988776655',
    email: 'amit.patel@email.com',
    address: 'Sector 5, Vashi, Navi Mumbai 400703',
    status: 'active',
  ),
  CustomerModel(
    id: 'c4',
    name: 'Sneha Reddy',
    phone: '+91 8765432109',
    email: 'sneha.reddy@email.com',
    address: 'Koramangala 5th Block, Bangalore 560095',
    status: 'inactive',
  ),
  CustomerModel(
    id: 'c5',
    name: 'Vikram Singh',
    phone: '+91 7654321098',
    email: 'vikram.singh@email.com',
    address: 'Connaught Place, New Delhi 110001',
    status: 'active',
  ),
];

final List<MealPlanModel> mockMealPlans = [
  MealPlanModel(
    id: 'mp1',
    planName: 'Dal Chawal Lunch',
    price: 4500,
    mealsType: 'Lunch',
    durationDays: 30,
    status: 'active',
  ),
  MealPlanModel(
    id: 'mp2',
    planName: 'Roti Sabzi Combo',
    price: 5000,
    mealsType: 'Lunch',
    durationDays: 30,
    status: 'active',
  ),
  MealPlanModel(
    id: 'mp3',
    planName: 'Full Day Tiffin',
    price: 8000,
    mealsType: 'Lunch + Dinner',
    durationDays: 30,
    status: 'active',
  ),
  MealPlanModel(
    id: 'mp4',
    planName: 'Breakfast Only',
    price: 2500,
    mealsType: 'Breakfast',
    durationDays: 30,
    status: 'inactive',
  ),
];

final List<SubscriptionModel> mockSubscriptions = [
  SubscriptionModel(
    id: 's1',
    customerId: 'c1',
    planId: 'mp1',
    startDate: DateTime.now().subtract(const Duration(days: 15)),
    endDate: DateTime.now().add(const Duration(days: 15)),
    status: 'active',
    autoRenewal: true,
  ),
  SubscriptionModel(
    id: 's2',
    customerId: 'c2',
    planId: 'mp2',
    startDate: DateTime.now().subtract(const Duration(days: 5)),
    endDate: DateTime.now().add(const Duration(days: 25)),
    status: 'active',
    autoRenewal: false,
  ),
  SubscriptionModel(
    id: 's3',
    customerId: 'c3',
    planId: 'mp3',
    startDate: DateTime.now().subtract(const Duration(days: 60)),
    endDate: DateTime.now().subtract(const Duration(days: 1)),
    status: 'expired',
    autoRenewal: false,
  ),
];

final List<DeliveryModel> mockDeliveries = [
  DeliveryModel(
    id: 'd1',
    customerId: 'c1',
    customerName: 'Rajesh Kumar',
    address: '42, Lamington Road, Grant Road East, Mumbai 400007',
    date: DateTime.now(),
    status: 'to_process',
    deliveryTime: null,
  ),
  DeliveryModel(
    id: 'd2',
    customerId: 'c2',
    customerName: 'Priya Sharma',
    address: 'Block A-12, Andheri West, Mumbai 400058',
    date: DateTime.now(),
    status: 'in_transit',
    deliveryTime: '12:30 PM',
  ),
  DeliveryModel(
    id: 'd3',
    customerId: 'c3',
    customerName: 'Amit Patel',
    address: 'Sector 5, Vashi, Navi Mumbai 400703',
    date: DateTime.now(),
    status: 'delivered',
    deliveryTime: '01:15 PM',
  ),
];



final List<NotificationModel> mockNotifications = [
  NotificationModel(
    id: 'n1',
    title: 'Subscription renewal due',
    body: 'Rajesh Kumar - Dal Chawal Lunch expires in 15 days.',
    time: DateTime.now().subtract(const Duration(hours: 2)),
    read: false,
  ),
  NotificationModel(
    id: 'n2',
    title: 'Payment received',
    body: '₹4,500 received from Rajesh Kumar via UPI.',
    time: DateTime.now().subtract(const Duration(days: 1)),
    read: true,
  ),
  NotificationModel(
    id: 'n3',
    title: 'New subscription',
    body: 'Priya Sharma subscribed to Roti Sabzi Combo.',
    time: DateTime.now().subtract(const Duration(days: 2)),
    read: true,
  ),
];

final List<Map<String, dynamic>> mockRecentActivity = [
  {'label': 'Payment received', 'subtitle': 'Rajesh Kumar • ₹4,500', 'time': '2 hours ago'},
  {'label': 'New subscription', 'subtitle': 'Priya Sharma • Roti Sabzi Combo', 'time': '1 day ago'},
  {'label': 'Delivery completed', 'subtitle': 'Amit Patel • Lunch', 'time': '1 day ago'},
];

final ReportSummary mockReportsData = ReportSummary(
  dailyRevenue: 12500,
  weeklyRevenue: 72000,
  monthlyRevenue: 285000,
  activeSubscriptions: 24,
  pendingDeliveries: 8,
  overduePayments: 3,
);

CustomerModel? getMockCustomerById(String id) {
  try {
    return mockCustomers.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

MealPlanModel? getMockMealPlanById(String id) {
  try {
    return mockMealPlans.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

List<SubscriptionModel> getMockSubscriptionsByCustomerId(String customerId) {
  return mockSubscriptions.where((s) => s.customerId == customerId).toList();
}
