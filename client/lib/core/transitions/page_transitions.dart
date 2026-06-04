import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Fade + slide (300ms) for all page transitions
Page<dynamic> slideTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeOut));
      const begin = Offset(0.03, 0);
      const end = Offset.zero;
      final slide = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
      return FadeTransition(
        opacity: animation.drive(fade),
        child: SlideTransition(
          position: animation.drive(slide),
          child: child,
        ),
      );
    },
  );
}
