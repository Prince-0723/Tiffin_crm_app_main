// API_INTEGRATION
// Endpoint: GET /api/meal-plans
// Purpose: Fetch all meal plans
// Request: (query optional: status)
// Response: { plans: List<MealPlanModel> }

// API_INTEGRATION
// Endpoint: POST /api/meal-plans
// Purpose: Create meal plan
// Request: { planName: String, price: double, mealsType: String, durationDays: int }
// Response: { id: String, planName: String, ... }

class MealPlanCreateRequest {
  const MealPlanCreateRequest({
    required this.planName,
    required this.price,
    required this.mealsType,
    required this.durationDays,
  });
  final String planName;
  final double price;
  final String mealsType;
  final int durationDays;
}

class MealPlanCreateResponse {
  const MealPlanCreateResponse({required this.id, required this.planName});
  final String id;
  final String planName;
}
