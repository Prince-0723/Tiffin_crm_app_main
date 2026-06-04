import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/notifications/notification_badge_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/auth_api.dart';
import '../../models/user_model.dart';
import '../../../../services/notification_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.selectedRole = 'vendor',
  });

  final String phone;
  final String selectedRole;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();

  final List<TextEditingController> _boxControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // Each box gets its OWN KeyboardListener FocusNode (skipTraversal so it
  // never steals focus from the TextField inside it)
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyListenerNodes = List.generate(
    6,
    (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
  );

  int _seconds = 60;
  Timer? _timer;
  bool _isVerifying = false;
  int _filledCount = 0;

  // ── Role helpers ──────────────────────────────────────────────────────────

  Color get _roleColor {
    switch (widget.selectedRole) {
      case 'customer':
        return const Color(0xFF1D9E75);
      case 'delivery_staff':
        return const Color(0xFFBA7517);
      case 'admin':
        return const Color(0xFFA32D2D);
      default:
        return const Color(0xFF5B2D8E);
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

  String get _roleName {
    switch (widget.selectedRole) {
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

  IconData get _roleIcon {
    switch (widget.selectedRole) {
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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    startTimer();
    for (final c in _boxControllers) {
      c.addListener(_updateFilledCount);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    for (final c in _boxControllers) {
      c.removeListener(_updateFilledCount);
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyListenerNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updateFilledCount() {
    final count = _boxControllers.where((c) => c.text.isNotEmpty).length;
    if (count != _filledCount) setState(() => _filledCount = count);
    _otpController.text = _boxControllers.map((c) => c.text).join();
  }

  void startTimer() {
    _seconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _updateFcmToken() async {
    try {
      await NotificationService().registerTokenAfterLogin();
    } catch (_) {}
  }

  void _showError(String msg) => AppSnackbar.error(context, msg);

  // ── OTP input logic ───────────────────────────────────────────────────────

  /// Called when text changes in box [index].
  void _onBoxChanged(int index, String value) {
    // Handle paste: if multiple digits land in one box, spread them out
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _boxControllers[i].text = digits[i];
        _boxControllers[i].selection = const TextSelection.collapsed(offset: 1);
      }
      final nextEmpty = _boxControllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty != -1) {
        _focusNodes[nextEmpty].requestFocus();
      } else {
        _focusNodes[5].unfocus();
        // Auto-submit on full paste
        if (_filledCount == 6) verifyOtp();
      }
      return;
    }

    // Normal single digit entered → advance
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_filledCount == 6) verifyOtp(); // auto-submit on last digit
      }
    }
    // Backspace on non-empty box just clears it (handled by TextField naturally)
    // Backspace on EMPTY box → handled by KeyboardListener below
  }

  /// Handles backspace when a box is already empty — moves focus back.
  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_boxControllers[index].text.isEmpty && index > 0) {
        _boxControllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  // ── Verify & Navigate ─────────────────────────────────────────────────────

  Future<void> verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError("Enter 6 digit OTP");
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await AuthApi.verifyOtp(widget.phone, otp);
      await SecureStorage.saveAccessToken(response.accessToken);
      await SecureStorage.saveRefreshToken(response.refreshToken);
      final user = response.user;
      final role = user.role;
      await SecureStorage.saveUserRole(role);
      await SecureStorage.saveUserId(user.id);
      await NotificationBadgeService.refreshNow();
      await _updateFcmToken();
      if (!mounted) return;
      setState(() => _isVerifying = false);
      await _navigateAfterLogin(context, user);
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ErrorHandler.show(context, e);
      }
    }
  }

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
        context.go(AppRoutes.vendorOnboarding, extra: widget.phone);
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

  // ── OTP Box Widget ────────────────────────────────────────────────────────

  Widget _buildOtpBox(int index) {
    // Rebuild whenever filled state might change
    final isFilled = _boxControllers[index].text.isNotEmpty;

    return KeyboardListener(
      focusNode: _keyListenerNodes[index],
      onKeyEvent: (event) => _onKeyEvent(index, event),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 54,
        decoration: BoxDecoration(
          color: isFilled
              ? _roleColor.withValues(alpha: 0.06)
              : const Color(0xFFFAFAFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFilled ? _roleColor : const Color(0xFFE0DAF0),
            width: isFilled ? 1.8 : 1.5,
          ),
        ),
        // ClipRRect ensures TextField doesn't visually overflow the rounded box
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Center(
            child: TextField(
              controller: _boxControllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
                color: isFilled ? _roleColor : const Color(0xFF1A0A2E),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _onBoxChanged(index, v),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTimerDone = _seconds == 0;
    final isAllFilled = _filledCount == 6;

    return Scaffold(
      backgroundColor: Colors.white,
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
              // ── Top header section ───────────────────────────────────────
              Container(
                color: const Color(0xFFF4F1FB),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _roleColor, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _roleColor.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _roleColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Logging in as $_roleName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _roleColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(_roleIcon, size: 14, color: _roleColor),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Shield icon + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _roleColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: _roleColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OTP Verification',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A0A2E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '6-digit code sent to',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF8B7BAE),
                                ),
                              ),
                              Text(
                                '+91 ${widget.phone}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF1A0A2E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Form section ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Label
                    const Text(
                      'ENTER VERIFICATION CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B7BAE),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 6 OTP boxes ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, _buildOtpBox),
                    ),

                    const SizedBox(height: 10),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _filledCount / 6,
                        backgroundColor: const Color(0xFFF0EBF9),
                        valueColor: AlwaysStoppedAnimation<Color>(_roleColor),
                        minHeight: 3,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Timer row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isTimerDone
                                ? const Color(0xFFE24B4A)
                                : const Color(0xFF8B7BAE),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isTimerDone ? 'Code expired' : 'Code expires in',
                            style: TextStyle(
                              fontSize: 12,
                              color: isTimerDone
                                  ? const Color(0xFFE24B4A)
                                  : const Color(0xFF8B7BAE),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isTimerDone ? '00:00' : _timerText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isTimerDone
                                  ? const Color(0xFFE24B4A)
                                  : _roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Verify button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAllFilled && !_isVerifying
                              ? _roleGradient
                              : [
                                  _roleColor.withValues(alpha: 0.35),
                                  _roleColor.withValues(alpha: 0.25),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isAllFilled && !_isVerifying
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
                          onTap: isAllFilled && !_isVerifying
                              ? verifyOtp
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.verified_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Verify OTP',
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

                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFF0EBF9),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'having trouble?',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFC4BAD9),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFF0EBF9),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Resend row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFF0EBF9),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A0A2E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTimerDone
                                      ? 'Tap to get a new code'
                                      : 'Resend in $_seconds sec',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isTimerDone
                                        ? _roleColor
                                        : const Color(0xFFB0A3C8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: isTimerDone
                                ? () {
                                    startTimer();
                                    for (final c in _boxControllers) {
                                      c.clear();
                                    }
                                    _focusNodes[0].requestFocus();
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isTimerDone
                                    ? _roleColor
                                    : const Color(0xFFF0EBF9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isTimerDone
                                      ? Colors.white
                                      : const Color(0xFFC4BAD9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Footer
                    const Text(
                      'Protected by 256-bit SSL encryption',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFFC4BAD9)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This code is valid for 10 minutes only',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF8B7BAE)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
