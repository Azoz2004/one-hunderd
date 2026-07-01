import 'package:flutter/material.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

class AppSnackbar {
  /// Shows a customized animated toast/snackbar message near the center of the screen.
  static void show({
    required BuildContext context,
    required String message,
    bool isSuccess = true,
    bool isInfo = false,
    bool isDelete = false,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AppSnackbarWidget(
        message: message,
        isSuccess: isSuccess,
        isInfo: isInfo,
        isDelete: isDelete,
        onDismissed: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _AppSnackbarWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final bool isInfo;
  final bool isDelete;
  final VoidCallback onDismissed;

  const _AppSnackbarWidget({
    required this.message,
    required this.isSuccess,
    this.isInfo = false,
    this.isDelete = false,
    required this.onDismissed,
  });

  @override
  State<_AppSnackbarWidget> createState() => _AppSnackbarWidgetState();
}

class _AppSnackbarWidgetState extends State<_AppSnackbarWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _hoverController;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late Animation<Offset> _hover;

  @override
  void initState() {
    super.initState();
    // 1. Entry and Exit Controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    // 2. Hover Controller for constant floating effect
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 3. Setup Animations
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );

    _slide = Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    _hover = Tween<Offset>(begin: const Offset(0.0, -0.12), end: const Offset(0.0, 0.12)).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeInOutSine,
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Play entry animation
    await _entryController.forward();
    // Start hover effect
    _hoverController.repeat(reverse: true);
    
    // Wait for the duration
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      _hoverController.stop();
      // Play exit animation
      await _entryController.reverse();
      // Remove from overlay
      widget.onDismissed();
    }
  }

  void _dismissEarly() {
    if (!mounted) return;
    _hoverController.stop();
    _entryController.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Position slightly below the top safe area
    final topPadding = MediaQuery.of(context).padding.top;
    final topOffset = topPadding + 20.0;

    return Positioned(
      top: topOffset,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entryController, _hoverController]),
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: SlideTransition(
                position: _slide,
                child: SlideTransition(
                  position: _hover,
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -2) {
                _dismissEarly();
              }
            },
            onTap: _dismissEarly,
            child: Container(
              decoration: BoxDecoration(
              color: widget.isDelete ? AppColors.charcoal : (widget.isInfo ? Colors.blueAccent : (widget.isSuccess ? AppColors.green : AppColors.error)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 2,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: (widget.isDelete ? AppColors.charcoal : (widget.isInfo ? Colors.blueAccent : (widget.isSuccess ? AppColors.green : AppColors.error))).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isDelete 
                        ? Icons.delete_outline_rounded 
                        : (widget.isInfo 
                            ? Icons.info_outline_rounded 
                            : (widget.isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded)),
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo', // Assuming Cairo font
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
