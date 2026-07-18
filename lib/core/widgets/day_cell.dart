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

  const DayCell({super.key, required this.dayNumber});

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
      duration: const Duration(milliseconds: 800), // تبطئة الأنيميشن قليلاً ليكون أكثر جاذبية
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
    final completed = provider.isDayCompleted(widget.dayNumber);

    if (completed) {
      _hasStartedInitialAnimation = true;
      // تأثير تدريجي متتابع عند فتح الشاشة
      final delayMs = 250 + (widget.dayNumber * 22); // زيادة خطوة التأخير إلى 22ms لتبطئة تتابع ظهور الخلايا
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          setState(() {
            _animateComplete = true;
          });
          _scaleController.forward(from: 0.0);
        }
      });
    } else {
      _animateComplete = false;
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

    if (completed && !_animateComplete) {
      if (!_hasStartedInitialAnimation) {
        _hasStartedInitialAnimation = true;
        // تأخير الأنيميشن عند إضافة عملية إدخار جديدة للسماح للـ Bottom Sheet بالإغلاق أولاً
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              _animateComplete = true;
            });
            _scaleController.forward(from: 0.0);
          }
        });
      }
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

    // تنسيق التاريخ بالعربية
    String formatDate(DateTime d) {
      const months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            top: 16,
            right: 24,
            bottom: 32 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اليوم ${widget.dayNumber}',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                    if (calendarDate != null)
                      Text(
                        formatDate(calendarDate),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                  ],
                ),
                const Spacer(),
                 Text(
                  '${dayTotal.toStringAsFixed(2)} JD',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                        fontFamily: 'sans-serif',
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // قائمة الإيداعات
            Text(
              deposits.length == 1
                  ? 'عملية إدخار واحدة في هذا اليوم'
                  : '${deposits.length} عمليات إدخار في هذا اليوم',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...deposits.map((dep) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${dep.amount.toStringAsFixed(2)} JD',
                                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'sans-serif',
                                        ),
                                  ),
                                  if (provider.isCooperativeMode && dep.depositedBy != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: dep.depositedBy == myUid
                                            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                            : const Color(0xFF667EEA).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: dep.depositedBy == myUid
                                              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                              : const Color(0xFF667EEA).withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        dep.depositedBy == myUid
                                            ? 'أنت'
                                            : (provider.cooperativeUserNames[dep.depositedBy] ?? 'الشريك'),
                                        style: TextStyle(
                                          color: dep.depositedBy == myUid
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFF667EEA),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (dep.notes != null && dep.notes!.isNotEmpty)
                                Text(dep.notes!,
                                    style: Theme.of(ctx).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTime(dep.date),
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.pop(ctx);
                              _showEditDepositDialog(context, provider, dep);
                            } else if (value == 'delete') {
                              Navigator.pop(ctx);
                              _showDeleteConfirmation(context, provider, dep);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(value: 'edit', child: Text('تعديل', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(fontSize: 14, color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
      ),
    );
  }

  void _showEditDepositDialog(BuildContext context, SavingsProvider provider, dynamic dep) {
    final amountController = TextEditingController(text: dep.amount.toString());
    final notesController = TextEditingController(text: dep.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الإيداع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              maxLength: 5,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(amountController.text);
              if (newAmount != null && newAmount > 0) {
                provider.updateDeposit(
                  dep.id,
                  amount: newAmount,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                Navigator.pop(ctx);
                if (context.mounted) {
                  AppSnackbar.show(
                    context: context,
                    message: 'تم تعديل الإيداع بنجاح ✏️',
                    isSuccess: true,
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SavingsProvider provider, dynamic dep) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الإيداع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteDeposit(dep.id);
              Navigator.pop(ctx);
              if (context.mounted) {
                AppSnackbar.show(
                  context: context,
                  message: 'تم حذف الإيداع بنجاح 🗑️',
                  isSuccess: false,
                  isDelete: true,
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
