import 'package:flutter/material.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

class AppSnackbar {
  static String _cleanMessage(String msg) {
    return msg
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FAFF}\u{1F000}-\u{1F02F}\u{1F0A0}-\u{1F0FF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Shows a customized animated toast/snackbar message near the center of the screen.
  static void show({
    required BuildContext context,
    required String message,
    bool isSuccess = true,
    bool isInfo = false,
    bool isDelete = false,
    bool isEdit = false,
    IconData? customIcon,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AppSnackbarWidget(
        message: _cleanMessage(message),
        isSuccess: isSuccess,
        isInfo: isInfo,
        isDelete: isDelete,
        isEdit: isEdit,
        customIcon: customIcon,
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
  final bool isEdit;
  final IconData? customIcon;
  final VoidCallback onDismissed;

  const _AppSnackbarWidget({
    required this.message,
    required this.isSuccess,
    this.isInfo = false,
    this.isDelete = false,
    this.isEdit = false,
    this.customIcon,
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

  static bool _isEditMessage(String msg) {
    return msg.contains('تعديل') || msg.contains('تحديث');
  }

  IconData _getIcon() {
    if (widget.customIcon != null) return widget.customIcon!;
    if (widget.isDelete) return Icons.delete_outline_rounded;
    if (widget.isEdit || _isEditMessage(widget.message)) {
      return Icons.edit_note_rounded;
    }
    if (widget.isInfo) {
      return Icons.tips_and_updates_rounded;
    }
    if (widget.isSuccess) {
      return Icons.task_alt_rounded;
    }
    return Icons.error_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // Position slightly below the top safe area
    final topPadding = MediaQuery.of(context).padding.top;
    final topOffset = topPadding + 20.0;
    final isEditType = widget.isEdit || _isEditMessage(widget.message);

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
                gradient: widget.isDelete
                    ? const LinearGradient(colors: [Color(0xFF2D3748), Color(0xFF1A202C)])
                    : (widget.isInfo
                        ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                        : (widget.isSuccess
                            ? (isEditType
                                ? const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF059669)])
                                : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]))
                            : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]))),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: (widget.isDelete
                            ? AppColors.charcoal
                            : (widget.isInfo
                                ? const Color(0xFF2563EB)
                                : (widget.isSuccess 
                                    ? (isEditType ? const Color(0xFF0D9488) : const Color(0xFF10B981))
                                    : AppColors.error)))
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIcon(),
                      color: Colors.white,
                      size: (isEditType && widget.customIcon == null) ? 26 : 24,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
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
