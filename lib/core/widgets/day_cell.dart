import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

/// A single cell in the 100-day grid, matching the physical sticker aesthetic.
///
/// Unpaid: thin-bordered circle with day number.
/// Paid: green circle with white checkmark.
/// Tapping a paid cell shows a bottom sheet listing all deposits for that day.
class DayCell extends StatefulWidget {
  final int dayNumber;
  final int animationTrigger;

  const DayCell({
    super.key,
    required this.dayNumber,
    this.animationTrigger = 0,
  });

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _animateComplete = false;
  bool _hasStartedInitialAnimation = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // تأثير تكبير وتصغير (الخلية بالكامل تكبر إلى 1.3 ثم ترتد وتستقر عند 1.08)
    _scaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 1.08).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 65,
        ),
      ],
    ).animate(_scaleController);

    final provider = context.read<SavingsProvider>();
    if (provider.isDayCompleted(widget.dayNumber)) {
      _hasStartedInitialAnimation = true;
      final delayMs = 300 + (widget.dayNumber * 22);
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          setState(() {
            _animateComplete = true;
          });
          _scaleController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationTrigger != oldWidget.animationTrigger) {
      final provider = context.read<SavingsProvider>();
      final completed = provider.isDayCompleted(widget.dayNumber);

      if (widget.animationTrigger % 2 != 0) {
        // ── الرقم الفردي: المستخدم فتح صفحة أخرى ──
        // نطفئ الخلية فوراً في الخلفية لتكون مطفأة وجاهزة
        if (_animateComplete) {
          setState(() {
            _animateComplete = false;
          });
        }
        _scaleController.reset();
      } else {
        // ── الرقم الزوجي: المستخدم رجع للشاشة الرئيسية ──
        // نبدأ تتابع الإضاءة والنبض المتتابع من الخلية 1 وحتى الأخيرة
        if (_animateComplete) {
          setState(() {
            _animateComplete = false;
          });
        }
        _scaleController.reset();

        if (completed) {
          final delayMs = 30 + (widget.dayNumber * 18);
          Future.delayed(Duration(milliseconds: delayMs), () {
            if (mounted) {
              setState(() {
                _animateComplete = true;
              });
              _scaleController.forward(from: 0.0);
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final completed = provider.isDayCompleted(widget.dayNumber);

    if (completed && !_animateComplete && !_hasStartedInitialAnimation) {
      // عند فتح التطبيق وتحميل البيانات لأول مرة من Firebase
      _hasStartedInitialAnimation = true;
      final delayMs = 350 + (widget.dayNumber * 22);
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          setState(() {
            _animateComplete = true;
          });
          _scaleController.forward(from: 0.0);
        }
      });
    } else if (!completed && _animateComplete) {
      _animateComplete = false;
      _hasStartedInitialAnimation = false;
      _scaleController.reverse();
    }

    final visualCompleted = _animateComplete;

    return GestureDetector(
      onTap: completed ? () => _showDetails(context, provider) : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Neumorphic Engraving + Inner Glow
            gradient: visualCompleted
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5, 1.0],
                    colors: [
                      Color(0xFFC8B59C), // Dark shadow top-left (makes it look pressed in)
                      Color(0xFFFFF7CC), // Soft golden glow inside the circle
                      Color(0xFFFFFFFF), // Highlight bottom-right (edge catching light)
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
            border: Border.all(
              color: visualCompleted ? const Color(0xFFA58D6D) : const Color(0xFFC0B8AD), // Lighter border than before, still darker than uncompleted
              width: visualCompleted ? 1.5 : 1.2,
            ),
            boxShadow: visualCompleted
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.08),
                      blurRadius: 3,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.only(top: 2.5, left: 1.5, right: 1.5),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '${widget.dayNumber}',
                    key: ValueKey<bool>(visualCompleted),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4A3E30), // Original dark brown
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, SavingsProvider provider) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final deposits = provider.getDepositsForDay(widget.dayNumber);
    final calendarDate = provider.getDateForDay(widget.dayNumber);
    final dayTotal = provider.totalForDay(widget.dayNumber);

    String formatDate(DateTime d) {
      const months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
      ];
      const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
    }

    String formatTime(DateTime d) {
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final period = d.hour >= 12 ? 'م' : 'ص';
      return '$h:$m $period';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _DayDetailsSheet(
        dayNumber: widget.dayNumber,
        deposits: deposits,
        calendarDate: calendarDate,
        dayTotal: dayTotal,
        myUid: myUid,
        provider: provider,
        formatDate: formatDate,
        formatTime: formatTime,
        onEdit: (dep) => _showEditDepositDialog(context, provider, dep),
        onDelete: (dep) => _showDeleteConfirmation(context, provider, dep),
      ),
    );
  }

  void _showEditDepositDialog(BuildContext context, SavingsProvider provider, dynamic dep) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق التعديل',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: _EditDepositDialog(dep: dep, provider: provider, parentContext: context),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, SavingsProvider provider, dynamic dep) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق الحذف',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: _DeleteConfirmDialog(dep: dep, provider: provider, parentContext: context),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Day Details Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════
class _DayDetailsSheet extends StatefulWidget {
  final int dayNumber;
  final List<dynamic> deposits;
  final DateTime? calendarDate;
  final double dayTotal;
  final String? myUid;
  final SavingsProvider provider;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final void Function(dynamic) onEdit;
  final void Function(dynamic) onDelete;

  const _DayDetailsSheet({
    required this.dayNumber,
    required this.deposits,
    required this.calendarDate,
    required this.dayTotal,
    required this.myUid,
    required this.provider,
    required this.formatDate,
    required this.formatTime,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends State<_DayDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle Bar ──
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Day badge
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFF7CC), Color(0xFFF5EDD0)],
                          ),
                          border: Border.all(color: const Color(0xFFA58D6D), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFC107).withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${widget.dayNumber}',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A3E30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اليوم ${widget.dayNumber} من 100',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                            ),
                            if (widget.calendarDate != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.formatDate(widget.calendarDate!),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Total amount badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${widget.dayTotal.toStringAsFixed(2)} JD',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Deposit Count label ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              widget.deposits.length == 1
                                  ? 'عملية إيداع واحدة'
                                  : '${widget.deposits.length} عمليات إيداع',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Deposit List ──
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      ...widget.deposits.asMap().entries.map((entry) {
                        final i = entry.key;
                        final dep = entry.value;
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(dep.id ?? i),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 280 + i * 80),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, value, child) => Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DepositCard(
                              dep: dep,
                              myUid: widget.myUid,
                              provider: widget.provider,
                              formatTime: widget.formatTime,
                              onEdit: () {
                                Navigator.pop(context);
                                widget.onEdit(dep);
                              },
                              onDelete: () {
                                Navigator.pop(context);
                                widget.onDelete(dep);
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual Deposit Card ──
class _DepositCard extends StatefulWidget {
  final dynamic dep;
  final String? myUid;
  final SavingsProvider provider;
  final String Function(DateTime) formatTime;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DepositCard({
    required this.dep,
    required this.myUid,
    required this.provider,
    required this.formatTime,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends State<_DepositCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dep = widget.dep;
    final isMyDeposit = dep.depositedBy == widget.myUid;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Amount Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${dep.amount.toStringAsFixed(2)} JD',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                        if (widget.provider.isCooperativeMode && dep.depositedBy != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMyDeposit
                                  ? const Color(0xFF4CAF50).withValues(alpha: 0.10)
                                  : const Color(0xFF667EEA).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isMyDeposit
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                    : const Color(0xFF667EEA).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isMyDeposit
                                  ? 'أنت'
                                  : (widget.provider.cooperativeUserNames[dep.depositedBy] ?? 'الشريك'),
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isMyDeposit
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          widget.formatTime(dep.date),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dep.notes != null && dep.notes!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dep.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIconButton(
                    icon: Icons.edit_rounded,
                    color: AppColors.charcoal,
                    bgColor: AppColors.cardFill,
                    onTap: widget.onEdit,
                    tooltip: 'تعديل',
                  ),
                  const SizedBox(width: 6),
                  _ActionIconButton(
                    icon: Icons.delete_rounded,
                    color: AppColors.error,
                    bgColor: AppColors.error.withValues(alpha: 0.08),
                    onTap: widget.onDelete,
                    tooltip: 'حذف',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon Button with press animation ──
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _pressed ? widget.color.withValues(alpha: 0.15) : widget.bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit Deposit Dialog
// ══════════════════════════════════════════════════════════════════════════════
class _EditDepositDialog extends StatefulWidget {
  final dynamic dep;
  final SavingsProvider provider;
  final BuildContext parentContext;

  const _EditDepositDialog({
    required this.dep,
    required this.provider,
    required this.parentContext,
  });

  @override
  State<_EditDepositDialog> createState() => _EditDepositDialogState();
}

class _EditDepositDialogState extends State<_EditDepositDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.dep.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: widget.dep.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        shadowColor: AppColors.charcoal.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.charcoal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تعديل الإيداع',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        'عدّل المبلغ أو الملاحظة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount Field
              _buildField(
                controller: _amountController,
                label: 'المبلغ (JD)',
                icon: Icons.account_balance_wallet_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),

              // Notes Field
              _buildField(
                controller: _notesController,
                label: 'ملاحظة (اختياري)',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AnimatedScale(
                      scale: _isSaving ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.charcoal,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                'حفظ التغييرات',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13.5,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.charcoal,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        fillColor: AppColors.surface,
        filled: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
        ),
      ),
    );
  }

  void _save() {
    final newAmount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (newAmount == null || newAmount <= 0) return;
    setState(() => _isSaving = true);
    widget.provider.updateDeposit(
      widget.dep.id,
      amount: newAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    Navigator.pop(context);
    if (widget.parentContext.mounted) {
      AppSnackbar.show(
        context: widget.parentContext,
        message: 'تم تعديل الإيداع بنجاح',
        isSuccess: true,
        isEdit: true,
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Delete Confirmation Dialog
// ══════════════════════════════════════════════════════════════════════════════
class _DeleteConfirmDialog extends StatefulWidget {
  final dynamic dep;
  final SavingsProvider provider;
  final BuildContext parentContext;

  const _DeleteConfirmDialog({
    required this.dep,
    required this.provider,
    required this.parentContext,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        shadowColor: AppColors.charcoal.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.15), width: 1.5),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'حذف الإيداع',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),

              // Amount preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
                ),
                child: Text(
                  '${widget.dep.amount.toStringAsFixed(2)} JD',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'هذا الإجراء لا يمكن التراجع عنه.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedScale(
                      scale: _deleting ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: ElevatedButton(
                        onPressed: _deleting ? null : _delete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                              )
                            : const Text(
                                'حذف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _delete() {
    setState(() => _deleting = true);
    widget.provider.deleteDeposit(widget.dep.id);
    Navigator.pop(context);
    if (widget.parentContext.mounted) {
      AppSnackbar.show(
        context: widget.parentContext,
        message: 'تم حذف الإيداع',
        isSuccess: false,
        isDelete: true,
      );
    }
  }
}

