// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import '../../../../core/router/app_routes.dart';
// import '../../../../core/theme/app_colors.dart';

// class OnboardingScreen extends StatefulWidget {
//   const OnboardingScreen({super.key});

//   @override
//   State<OnboardingScreen> createState() => _OnboardingScreenState();
// }

// class _OnboardingScreenState extends State<OnboardingScreen>
//     with TickerProviderStateMixin {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;

//   // Animation Controllers
//   late AnimationController _iconAnimationController;
//   late AnimationController _textAnimationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _fadeAnimation;

//   // Different icons for each slide
//   static const List<Map<String, dynamic>> _slides = [
//     {
//       'title': 'Prepare',
//       'subtitle': 'Manage your tiffin business with ease',
//       'icon': Icons.restaurant_menu,
//       'iconColor': Color(0xFF4CAF50),
//     },
//     {
//       'title': 'Customer Manage',
//       'subtitle': 'Keep track of all your customers',
//       'icon': Icons.people_outline,
//       'iconColor': Color(0xFF2196F3),
//     },
//     {
//       'title': 'Contact',
//       'subtitle': 'Stay connected with WhatsApp and SMS',
//       'icon': Icons.chat_bubble_outline,
//       'iconColor': Color(0xFF25D366),
//     },
//     {
//       'title': 'Save Time',
//       'subtitle': 'Automate subscriptions and deliveries',
//       'icon': Icons.access_time_filled,
//       'iconColor': Color(0xFFFF9800),
//     },
//     {
//       'title': 'Pin Location',
//       'subtitle': 'Quick access to what matters most',
//       'icon': Icons.location_on,
//       'iconColor': Color(0xFFE91E63),
//     },
//   ];

//   @override
//   void initState() {
//     super.initState();

//     // Icon scale animation
//     _iconAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//     _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _iconAnimationController,
//         curve: Curves.elasticOut,
//       ),
//     );

//     // Text slide animation
//     _textAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _textAnimationController,
//             curve: Curves.easeOutCubic,
//           ),
//         );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _textAnimationController, curve: Curves.easeIn),
//     );

//     // Start initial animation
//     _iconAnimationController.forward();
//     _textAnimationController.forward();
//   }

//   @override
//   void dispose() {
//     _iconAnimationController.dispose();
//     _textAnimationController.dispose();
//     _pageController.dispose();
//     super.dispose();
//   }

//   void _onPageChanged(int page) {
//     setState(() => _currentPage = page);

//     // Reset and replay animations
//     _iconAnimationController.reset();
//     _textAnimationController.reset();
//     _iconAnimationController.forward();
//     _textAnimationController.forward();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final size = MediaQuery.of(context).size;

//     return Scaffold(
//       backgroundColor: theme.colorScheme.surface,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Skip button
//             Align(
//               alignment: Alignment.topRight,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: TextButton(
//                   onPressed: () => context.go(AppRoutes.login),
//                   child: Text(
//                     'Skip',
//                     style: theme.textTheme.labelLarge?.copyWith(
//                       color: AppColors.primary,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//             Expanded(
//               child: PageView.builder(
//                 controller: _pageController,
//                 onPageChanged: _onPageChanged,
//                 itemCount: _slides.length,
//                 itemBuilder: (context, i) {
//                   final slide = _slides[i];
//                   return _buildSlide(slide, theme, size);
//                 },
//               ),
//             ),

//             // Animated Page Indicator
//             _buildPageIndicator(),

//             const SizedBox(height: 24),

//             // Next / Get Started Button
//             _buildActionButton(theme),

//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSlide(Map<String, dynamic> slide, ThemeData theme, Size size) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 32),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Animated Icon with floating effect
//           AnimatedBuilder(
//             animation: _iconAnimationController,
//             builder: (context, child) {
//               return Transform.scale(
//                 scale: _scaleAnimation.value,
//                 child: Container(
//                   width: 160,
//                   height: 160,
//                   decoration: BoxDecoration(
//                     color: (slide['iconColor'] as Color).withOpacity(0.1),
//                     shape: BoxShape.circle,
//                     boxShadow: [
//                       BoxShadow(
//                         color: (slide['iconColor'] as Color).withOpacity(0.2),
//                         blurRadius: 30,
//                         spreadRadius: 5,
//                       ),
//                     ],
//                   ),
//                   child: Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       // Floating animation
//                       TweenAnimationBuilder<double>(
//                         tween: Tween(begin: 0, end: 1),
//                         duration: const Duration(seconds: 2),
//                         builder: (context, value, child) {
//                           return Transform.translate(
//                             offset: Offset(0, -8 + (value * 4)),
//                             child: Icon(
//                               slide['icon'] as IconData,
//                               size: 80,
//                               color: slide['iconColor'] as Color,
//                             ),
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),

//           const SizedBox(height: 48),

//           // Animated Title
//           SlideTransition(
//             position: _slideAnimation,
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: Text(
//                 slide['title'] as String,
//                 style: theme.textTheme.headlineLarge?.copyWith(
//                   fontWeight: FontWeight.w800,
//                   color: AppColors.onSurface,
//                   letterSpacing: -0.5,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),

//           const SizedBox(height: 16),

//           // Animated Subtitle
//           SlideTransition(
//             position: _slideAnimation,
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: Text(
//                 slide['subtitle'] as String,
//                 style: theme.textTheme.bodyLarge?.copyWith(
//                   color: theme.colorScheme.onSurfaceVariant,
//                   height: 1.5,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPageIndicator() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: List.generate(
//         _slides.length,
//         (i) => AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeInOut,
//           margin: const EdgeInsets.symmetric(horizontal: 4),
//           width: _currentPage == i ? 32 : 12,
//           height: 12,
//           decoration: BoxDecoration(
//             color: _currentPage == i
//                 ? AppColors.primary
//                 : AppColors.primary.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(6),
//             boxShadow: _currentPage == i
//                 ? [
//                     BoxShadow(
//                       color: AppColors.primary.withOpacity(0.4),
//                       blurRadius: 8,
//                       spreadRadius: 1,
//                     ),
//                   ]
//                 : null,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButton(ThemeData theme) {
//     final isLastPage = _currentPage == _slides.length - 1;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 24),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         width: double.infinity,
//         height: 56,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
//             begin: Alignment.centerLeft,
//             end: Alignment.centerRight,
//           ),
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: AppColors.primary.withOpacity(0.4),
//               blurRadius: 16,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             borderRadius: BorderRadius.circular(16),
//             onTap: () {
//               if (!isLastPage) {
//                 _pageController.nextPage(
//                   duration: const Duration(milliseconds: 400),
//                   curve: Curves.easeInOutCubic,
//                 );
//               } else {
//                 context.go(AppRoutes.login);
//               }
//             },
//             child: Center(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     isLastPage ? 'Get Started' : 'Next',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                   if (!isLastPage) ...[
//                     const SizedBox(width: 8),
//                     const AnimatedArrow(),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Animated arrow widget
// class AnimatedArrow extends StatefulWidget {
//   const AnimatedArrow({super.key});

//   @override
//   State<AnimatedArrow> createState() => _AnimatedArrowState();
// }

// class _AnimatedArrowState extends State<AnimatedArrow>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     )..repeat(reverse: true);
//     _animation = Tween<double>(
//       begin: 0,
//       end: 4,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Transform.translate(
//           offset: Offset(_animation.value, 0),
//           child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
//         );
//       },
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _iconAnimationController;
  late AnimationController _textAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ONLY JSON ADDED INSTEAD OF ICONS
  static const List<Map<String, dynamic>> _slides = [
    {
      'title': 'Prepare',
      'subtitle': 'Manage your tiffin business with ease',
      'lottie': 'assets/lottie/prepare.json',
      'iconColor': Color(0xFF4CAF50),
    },
    {
      'title': 'Customer Manage',
      'subtitle': 'Keep track of all your customers',
      'lottie': 'assets/lottie/managecustomers.json',
      'iconColor': Color(0xFF2196F3),
    },
    {
      'title': 'Contact',
      'subtitle': 'Stay connected with WhatsApp and SMS',
      'lottie': 'assets/lottie/contact.json',
      'iconColor': Color(0xFF25D366),
    },
    {
      'title': 'Save Time',
      'subtitle': 'Automate subscriptions and deliveries',
      'lottie': 'assets/lottie/delivery.json',
      'iconColor': Color(0xFFFF9800),
    },
    {
      'title': 'Pin Location',
      'subtitle': 'Quick access to what matters most',
      'lottie': 'assets/lottie/Location.json',
      'iconColor': Color(0xFFE91E63),
    },
  ];

  @override
  void initState() {
    super.initState();

    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.easeIn),
    );

    _iconAnimationController.forward();
    _textAnimationController.forward();
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _textAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);

    _iconAnimationController.reset();
    _textAnimationController.reset();
    _iconAnimationController.forward();
    _textAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_seen', true);
                    if (context.mounted) context.go(AppRoutes.roleSelection);
                  },
                  child: Text(
                    'Skip',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return _buildSlide(slide, theme, size);
                },
              ),
            ),

            _buildPageIndicator(),
            const SizedBox(height: 24),
            _buildActionButton(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide, ThemeData theme, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _iconAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: (slide['iconColor'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (slide['iconColor'] as Color).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Lottie.asset(slide['lottie'], fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                slide['title'] as String,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 16),

          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                slide['subtitle'] as String,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == i ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: _currentPage == i
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: _currentPage == i
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (!isLastPage) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              } else {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_seen', true);
                if (context.mounted) context.go(AppRoutes.roleSelection);
              }
            },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!isLastPage) ...[
                    const SizedBox(width: 8),
                    const AnimatedArrow(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedArrow extends StatefulWidget {
  const AnimatedArrow({super.key});

  @override
  State<AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<AnimatedArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
        );
      },
    );
  }
}
