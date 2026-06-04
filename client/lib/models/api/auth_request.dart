// API_INTEGRATION
// Endpoint: POST /api/auth/login
// Purpose: Send OTP to phone number for login
// Request: { phone: String }
// Response: { success: bool, message: String }

class AuthLoginRequest {
  const AuthLoginRequest({required this.phone});
  final String phone;
}

class AuthLoginResponse {
  const AuthLoginResponse({required this.success, this.message});
  final bool success;
  final String? message;
}
