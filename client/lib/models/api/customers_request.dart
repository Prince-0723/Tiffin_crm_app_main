// API_INTEGRATION
// Endpoint: GET /api/customers
// Purpose: Fetch all customers
// Request: (query optional: status, search)
// Response: { customers: List<CustomerModel> }

class CustomersListResponse {
  const CustomersListResponse({required this.customers});
  final List<dynamic> customers;
}

// API_INTEGRATION
// Endpoint: POST /api/customers
// Purpose: Add new customer
// Request: { name: String, phone: String, email?: String, address?: String }
// Response: { id: String, name: String, phone: String, ... }

class CustomerCreateRequest {
  const CustomerCreateRequest({
    required this.name,
    required this.phone,
    this.email,
    this.address,
  });
  final String name;
  final String phone;
  final String? email;
  final String? address;
}

class CustomerCreateResponse {
  const CustomerCreateResponse({required this.id, required this.name});
  final String id;
  final String name;
}

// API_INTEGRATION
// Endpoint: PUT /api/customers/:id
// Purpose: Update customer
// Request: { name: String, phone: String, email?: String, address?: String }
// Response: { id: String, name: String, ... }

class CustomerUpdateRequest {
  const CustomerUpdateRequest({
    required this.name,
    required this.phone,
    this.email,
    this.address,
  });
  final String name;
  final String phone;
  final String? email;
  final String? address;
}
