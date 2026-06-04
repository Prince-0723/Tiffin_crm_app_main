// API_INTEGRATION
// Endpoint: POST /api/auth/verify-otp
// Purpose: Verify OTP and return JWT
// Request: { phone: String, otp: String }
// Response: { token: String, userId: String, userName: String }

class AuthVerifyOtpRequest {
  const AuthVerifyOtpRequest({required this.phone, required this.otp});
  final String phone;
  final String otp;
}

class AuthVerifyOtpResponse {
  const AuthVerifyOtpResponse({
    required this.token,
    required this.userId,
    this.userName,
  });
  final String token;
  final String userId;
  final String? userName;
}
