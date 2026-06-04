// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import '../../../../core/router/app_routes.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/utils/error_handler.dart';
// import '../../data/auth_api.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key, this.selectedRole = 'vendor'});

//   final String selectedRole;

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen>
//     with TickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final _phoneController = TextEditingController();

//   bool _isLoading = false;

//   static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');

//   @override
//   void dispose() {
//     _phoneController.dispose();
//     super.dispose();
//   }

//   String? _validatePhone(String? value) {
//     final v = value?.trim().replaceAll(RegExp(r'\D'), '') ?? '';
//     if (v.isEmpty) return "Mobile number required";
//     if (v.length != 10) return "Enter 10 digit number";
//     if (!_phoneRegex.hasMatch(v)) return "Invalid mobile number";
//     return null;
//   }

//   Future<void> _handleLogin() async {
//     FocusScope.of(context).unfocus();

//     if (!_formKey.currentState!.validate()) return;

//     final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
//     if (phone.length != 10) return;

//     setState(() => _isLoading = true);

//     try {
//       await AuthApi.sendOtp(phone);
//       if (!mounted) return;
//       context.push(
//         AppRoutes.otp,
//         extra: <String, String>{
//           'phone': phone,
//           'selectedRole': widget.selectedRole,
//         },
//       );
//     } catch (e) {
//       if (mounted) ErrorHandler.show(context, e);
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       backgroundColor: theme.colorScheme.surface,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24),
//           child: Column(
//             children: [
//               const SizedBox(height: 50),

//               /// Role badge (navigation helper only; backend sets actual role)
//               _RoleBadge(selectedRole: widget.selectedRole),
//               const SizedBox(height: 20),

//               /// LOGO
//               TweenAnimationBuilder(
//                 duration: const Duration(milliseconds: 700),
//                 tween: Tween(begin: 0.85, end: 1.0),
//                 curve: Curves.easeOutBack,
//                 builder: (context, scale, child) =>
//                     Transform.scale(scale: scale, child: child),
//                 child: Container(
//                   height: 90,
//                   width: 90,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: AppColors.primary.withValues(alpha: 0.12),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Image.asset(
//                       "assets/images/app_logo.png",
//                       fit: BoxFit.contain,
//                     ),
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 26),

//               Text(
//                 "Get started ",
//                 style: theme.textTheme.headlineMedium?.copyWith(
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),

//               const SizedBox(height: 6),

//               Text(
//                 "Login using your mobile number",
//                 style: theme.textTheme.bodyMedium?.copyWith(
//                   color: theme.colorScheme.onSurfaceVariant,
//                 ),
//               ),

//               const SizedBox(height: 36),

//               /// LOGIN CARD
//               Container(
//                 padding: const EdgeInsets.all(22),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(20),
//                   color: theme.cardColor,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withValues(alpha: 0.06),
//                       blurRadius: 25,
//                       offset: const Offset(0, 10),
//                     ),
//                   ],
//                 ),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       /// PHONE FIELD
//                       TextFormField(
//                         controller: _phoneController,
//                         keyboardType: TextInputType.phone,
//                         maxLength: 10,
//                         validator: _validatePhone,
//                         style: const TextStyle(fontSize: 16),
//                         decoration: InputDecoration(
//                           labelText: "Mobile Number",
//                           prefixText: "+91  ",
//                           counterText: "",
//                           filled: true,
//                           fillColor: theme.colorScheme.surfaceContainerHighest,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(14),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(14),
//                             borderSide: BorderSide(
//                               color: AppColors.primary,
//                               width: 1.2,
//                             ),
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 22),

//                       /// LOGIN BUTTON
//                       SizedBox(
//                         width: double.infinity,
//                         height: 52,
//                         child: FilledButton(
//                           onPressed: _isLoading ? null : _handleLogin,
//                           style: FilledButton.styleFrom(
//                             backgroundColor: AppColors.primary,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14),
//                             ),
//                           ),
//                           child: _isLoading
//                               ? const SizedBox(
//                                   height: 22,
//                                   width: 22,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2.4,
//                                     color: Colors.white,
//                                   ),
//                                 )
//                               : const Text(
//                                   "Send OTP",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 26),

//               /// TRUECALLER
//               SizedBox(
//                 width: double.infinity,
//                 height: 54,
//                 child: OutlinedButton(
//                   onPressed: () => context.push(AppRoutes.truecaller),
//                   style:
//                       OutlinedButton.styleFrom(
//                         backgroundColor: Colors.white,
//                         elevation: 0,
//                         side: BorderSide(
//                           color: Colors.grey.shade300,
//                           width: 1.2,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         shadowColor: Colors.black.withValues(alpha: 0.05),
//                       ).copyWith(
//                         overlayColor: WidgetStateProperty.all(
//                           Colors.grey.withValues(alpha: 0.08),
//                         ),
//                       ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       // TRUECALLER WEBP LOGO
//                       Image.asset(
//                         "assets/images/truecaller.webp",
//                         height: 40,
//                         width: 40,
//                       ),

//                       const SizedBox(width: 12),

//                       const Text(
//                         "Continue with Truecaller",
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 30),

//               Text(
//                 "By continuing you agree to Terms & Privacy Policy",
//                 textAlign: TextAlign.center,
//                 style: theme.textTheme.bodySmall?.copyWith(
//                   color: theme.colorScheme.onSurfaceVariant,
//                 ),
//               ),

//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _RoleBadge extends StatelessWidget {
//   const _RoleBadge({required this.selectedRole});

//   final String selectedRole;

//   static IconData _icon(String role) {
//     switch (role) {
//       case 'customer':
//         return Icons.person_rounded;
//       case 'delivery_staff':
//         return Icons.delivery_dining_rounded;
//       case 'admin':
//         return Icons.admin_panel_settings_rounded;
//       default:
//         return Icons.store_rounded;
//     }
//   }

//   static String _title(String role) {
//     switch (role) {
//       case 'customer':
//         return 'Customer';
//       case 'delivery_staff':
//         return 'Delivery';
//       case 'admin':
//         return 'Admin';
//       default:
//         return 'Vendor';
//     }
//   }

//   static Color _color(String role) {
//     switch (role) {
//       case 'customer':
//         return AppColors.success;
//       case 'delivery_staff':
//         return AppColors.warning;
//       case 'admin':
//         return AppColors.danger;
//       default:
//         return AppColors.primary;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final roleColor = _color(selectedRole);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: roleColor.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: roleColor),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(_icon(selectedRole), size: 16, color: roleColor),
//           const SizedBox(width: 6),
//           Text(
//             'Logging in as ${_title(selectedRole)}',
//             style: theme.textTheme.labelMedium?.copyWith(color: roleColor),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/notifications/notification_badge_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/auth_api.dart';
import '../../models/user_model.dart';
import '../../../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.selectedRole = 'vendor'});

  final String selectedRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isValid = false;

  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final v = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final valid = v.length == 10 && _phoneRegex.hasMatch(v);
    if (valid != _isValid) setState(() => _isValid = valid);
  }

  String? _validatePhone(String? value) {
    final v = value?.trim().replaceAll(RegExp(r'\D'), '') ?? '';
    if (v.isEmpty) return 'Mobile number required';
    if (v.length != 10) return 'Enter 10 digit number';
    if (!_phoneRegex.hasMatch(v)) return 'Must start with 6, 7, 8, or 9';
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) return;
    setState(() => _isLoading = true);
    try {
      await AuthApi.sendOtp(phone);
      if (!mounted) return;
      context.push(
        AppRoutes.otp,
        extra: <String, String>{
          'phone': phone,
          'selectedRole': widget.selectedRole,
        },
      );
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element
  Future<void> _updateFcmToken() async {
    try {
      await NotificationService().registerTokenAfterLogin();
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _navigateAfterLogin(BuildContext context, UserModel user) async {
    final role = user.role;
    if (role == 'vendor') {
      UserModel profile;
      try {
        profile = await AuthApi.getProfile();
      } catch (_) {
        profile = user;
      }
      if (!context.mounted) return;
      if (!profile.isVendorProfileComplete) {
        context.go(AppRoutes.vendorOnboarding, extra: user.phone);
      } else {
        context.go(AppRoutes.dashboard);
      }
      return;
    }
    if (!context.mounted) return;
    switch (role) {
      case 'customer':
        context.go(AppRoutes.customerHome);
        break;
      case 'delivery_staff':
        context.go(AppRoutes.deliveryDashboard);
        break;
      case 'admin':
        context.go(AppRoutes.adminDashboard);
        break;
      default:
        context.go(AppRoutes.dashboard);
    }
  }

  Color get _roleColor {
    switch (widget.selectedRole) {
      case 'customer':
        return const Color(0xFF1D9E75);
      case 'delivery_staff':
        return const Color(0xFFBA7517);
      case 'admin':
        return const Color(0xFFA32D2D);
      default:
        return AppColors.primary;
    }
  }

  List<Color> get _roleGradient {
    switch (widget.selectedRole) {
      case 'customer':
        return [const Color(0xFF1DB87A), const Color(0xFF0A5C3A)];
      case 'delivery_staff':
        return [const Color(0xFFE8A020), const Color(0xFF8B4A00)];
      case 'admin':
        return [const Color(0xFFD64444), const Color(0xFF7A1212)];
      default:
        return [const Color(0xFF7C3AED), const Color(0xFF3B1472)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      // ── Back arrow AppBar ─────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F1FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _roleColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top light section ───────────────────────────────
              Container(
                color: const Color(0xFFF4F1FB),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    // Role badge
                    _RoleBadge(
                      selectedRole: widget.selectedRole,
                      roleColor: _roleColor,
                    ),
                    const SizedBox(height: 24),

                    // Illustration
                    SizedBox(
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Phone mockup
                          Positioned(
                            left: 40,
                            child: Container(
                              width: 72,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _roleColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _roleColor.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      3,
                                      (i) => Container(
                                        width: 14,
                                        height: 18,
                                        margin: EdgeInsets.only(
                                          left: i == 0 ? 0 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: i == 2
                                              ? _roleColor.withValues(
                                                  alpha: 0.85,
                                                )
                                              : _roleColor.withValues(
                                                  alpha: 0.08,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: _roleColor.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: i == 2
                                            ? Center(
                                                child: Container(
                                                  width: 6,
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          1,
                                                        ),
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: 50,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _roleColor.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Lock circle
                          Positioned(
                            right: 30,
                            top: 0,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _roleColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                color: _roleColor,
                                size: 24,
                              ),
                            ),
                          ),

                          // Check circle
                          Positioned(
                            right: 10,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _roleColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: _roleColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom white form ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Verify your identity',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A0A2E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your registered mobile number to receive OTP',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8B7BAE),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Label
                      const Text(
                        'MOBILE NUMBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B7BAE),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        validator: _validatePhone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1A0A2E),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter 10-digit number',
                          hintStyle: const TextStyle(
                            color: Color(0xFFC4BAD9),
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: IntrinsicHeight(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16),
                                Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _roleColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: const Color(0xFFE0DAF0),
                                ),
                                const SizedBox(width: 10),
                              ],
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _roleColor.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _roleColor,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE24B4A),
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE24B4A),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Send OTP button ──────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isLoading || !_isValid
                                ? [
                                    _roleColor.withValues(alpha: 0.35),
                                    _roleColor.withValues(alpha: 0.25),
                                  ]
                                : _roleGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isValid && !_isLoading
                              ? [
                                  BoxShadow(
                                    color: _roleColor.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading || !_isValid
                                ? null
                                : _handleLogin,
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Send OTP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Footer
                      const Text(
                        'Protected by 256-bit encryption · Your data is safe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC4BAD9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'By continuing you agree to Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B7BAE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.selectedRole, required this.roleColor});

  final String selectedRole;
  final Color roleColor;

  static String _title(String role) {
    switch (role) {
      case 'customer':
        return 'Customer';
      case 'delivery_staff':
        return 'Delivery';
      case 'admin':
        return 'Admin';
      default:
        return 'Vendor';
    }
  }

  static IconData _icon(String role) {
    switch (role) {
      case 'customer':
        return Icons.person_outline_rounded;
      case 'delivery_staff':
        return Icons.delivery_dining_rounded;
      case 'admin':
        return Icons.shield_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: roleColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Logging in as ${_title(selectedRole)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: roleColor,
            ),
          ),
          const SizedBox(width: 6),
          Icon(_icon(selectedRole), size: 14, color: roleColor),
        ],
      ),
    );
  }
}
