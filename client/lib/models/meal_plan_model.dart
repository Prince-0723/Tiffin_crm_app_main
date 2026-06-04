class MealPlanModel {
  const MealPlanModel({
    required this.id,
    required this.planName,
    required this.price,
    required this.mealsType,
    required this.durationDays,
    this.status = 'active',
  });

  final String id;
  final String planName;
  final double price;
  final String mealsType;
  final int durationDays;
  final String status;
}
