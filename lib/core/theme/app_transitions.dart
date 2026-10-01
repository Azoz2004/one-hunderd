import 'package:flutter/material.dart';

/// Enum to specify the slide direction for lateral/side transitions
enum SlideSide { right, left, top, bottom }

/// ─── 1. Full Page Scale & Zoom Transition Route ──────────────────────────────
/// An expressive, unmistakable full-screen page route with scale-up (0.85 -> 1.0),
/// slight upward slide, and smooth fade-in.
class AppScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppScalePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 460),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Push:  slides up from bottom of screen  (0,1) → (0,0)
            // Pop:   slides back down off-screen       (0,0) → (0,1)
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: slide,
              child: RepaintBoundary(
                child: child,
              ),
            );
          },
        );
}

/// ─── 2. Full Page Transitions Builder (for ThemeData) ─────────────────────────
class AppScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedIn = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final scaleIn = Tween<double>(begin: 0.86, end: 1.0).animate(curvedIn);
    final slideIn = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(curvedIn);
    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curvedIn);

    final curvedOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final scaleOut = Tween<double>(begin: 1.0, end: 0.90).animate(curvedOut);
    final fadeOut = Tween<double>(begin: 1.0, end: 0.60).animate(curvedOut);

    return ScaleTransition(
      scale: scaleOut,
      child: FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(
          position: slideIn,
          child: ScaleTransition(
            scale: scaleIn,
            child: FadeTransition(
              opacity: fadeIn,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── 3. Side / Lateral Page Route ─────────────────────────────────────────────
/// Slides smoothly in from the specified edge (Right for RTL, Left, etc.)
class AppSideSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideSide side;

  AppSideSlidePageRoute({
    required this.page,
    this.side = SlideSide.right,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset beginOffset;
            switch (side) {
              case SlideSide.right:
                beginOffset = const Offset(1.0, 0.0);
                break;
              case SlideSide.left:
                beginOffset = const Offset(-1.0, 0.0);
                break;
              case SlideSide.top:
                beginOffset = const Offset(0.0, -1.0);
                break;
              case SlideSide.bottom:
                beginOffset = const Offset(0.0, 1.0);
                break;
            }

            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final slideAnim = Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curved);
            final fadeAnim = Tween<double>(begin: 0.3, end: 1.0).animate(curved);

            return SlideTransition(
              position: slideAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: child,
              ),
            );
          },
        );
}

/// ─── 4. Vault-Style Bouncy Pop-up Dialog Helper ──────────────────────────────
/// Open: strong elastic bounce from 0.55.  Close: fast fade-out (matches Vault).
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'AppDialog',
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim1, anim2) => builder(ctx),
    transitionBuilder: (ctx, anim1, anim2, child) {
      // Use easeOutBack for opening (elastic bounce), NO reverseCurve
      // so closing mirrors the Vault: simple fade + gentle shrink, no inward snap
      final bounceCurve = CurvedAnimation(
        parent: anim1,
        curve: Curves.easeOutBack,
        // No reverseCurve → closing uses linear reverse which feels like Vault
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.55, end: 1.0).animate(bounceCurve),
        child: FadeTransition(
          // anim1 directly for fade — quick fade-out on close like Vault
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

/// ─── 5. Universal Navigation Helper ──────────────────────────────────────────
class AppNav {
  AppNav._();

  /// Push a full-screen page with the custom Zoom + Elevation animation
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      AppScalePageRoute<T>(page: page),
    );
  }

  /// Push a side page sliding from the right or left edge
  static Future<T?> pushSide<T>(
    BuildContext context,
    Widget page, {
    SlideSide side = SlideSide.right,
  }) {
    return Navigator.push<T>(
      context,
      AppSideSlidePageRoute<T>(page: page, side: side),
    );
  }

  /// Open a pop-up dialog with the bouncy Vault animation
  static Future<T?> showVaultDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    return showAppDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
}
