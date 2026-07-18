import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/widgets/gamification_dialogs.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/services/notification_service.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';

/// A modal bottom sheet form for logging a daily deposit.
/// Supports multiple deposits per day.
class DepositDialog extends StatefulWidget {
  const DepositDialog({super.key});

  // ─── الحل الصحيح للمزامنة مع الكيبورد ──────────────────────────────────────
  // يجب استخدام padding من سياق الـ builder مباشرة (وليس سياق الأب)
  // لأن MediaQuery داخل الـ BottomSheet يتلقى تحديثات viewInsets الصحيحة
  // المتزامنة مع أنيميشن الكيبورد من النظام مباشرةً
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        // هذا الـ Padding يأخذ قيمة viewInsets من sheetContext
        // وهو يتحدث تلقائياً مع كل إطار للأنيميشن — بدون أي تأخير
        padding: MediaQuery.viewInsetsOf(sheetContext),
        child: const DepositDialog(),
      ),
    );
  }

  @override
  State<DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<DepositDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SavingsProvider>();
    final nextGridDay = provider.completedDays + 1;
    if (nextGridDay <= 100 && !provider.hasTodayDeposit) {
      _amountController.text = nextGridDay.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountController.text.trim());
    final notes = _notesController.text.trim();
    final provider = context.read<SavingsProvider>();

    try {
      await provider.logDeposit(
        amount: amount,
        notes: notes.isEmpty ? null : notes,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.show(
        context: context,
        message: e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
      return;
    }

    final updatedDays = provider.completedDays;
    if (!mounted) return;
    AppSnackbar.show(
      context: context,
      message: 'تم تسجيل الإيداع بنجاح 💰',
      isSuccess: true,
    );

    final nav = Navigator.of(context);
    nav.pop();

    final notificationService = NotificationService();
    await notificationService.cancelEveningNotification();
    await notificationService.schedulePassiveAggressiveReminder();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = nav.context;
      if (!ctx.mounted) return;
      await checkAndShowMilestone(ctx, updatedDays);
      if (!ctx.mounted) return;
      await checkAndShowWeeklyQuest(ctx, updatedDays);
      if (!ctx.mounted) return;
      await checkAndShowDailyInsight(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SavingsProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شريط السحب
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // صف العنوان وزر الإغلاق
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل إيداع جديد',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.charcoal,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اليوم ${provider.hasTodayDeposit ? provider.completedDays : provider.completedDays + 1} من 100',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.charcoal,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.borderLight.withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // حقل المبلغ
                // ─── الحل الصحيح لإظهار JD دائماً ──────────────────────────
                // suffix و suffixText لا يظهران إلا عند التركيز (سلوك Flutter المدمج)
                // suffixIcon هو الوحيد الذي يظهر دائماً بغض النظر عن التركيز
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: false,
                  maxLength: 5,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.charcoal,
                    ),
                    // suffixIcon يظهر دائماً بخلاف suffix/suffixText
                    suffixIcon: Align(
                      alignment: Alignment.center,
                      widthFactor: 1.0,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(end: 14),
                        child: Text(
                          'JD',
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال المبلغ';
                    }
                    final n = double.tryParse(value.trim());
                    if (n == null || n <= 0) {
                      return 'أدخل مبلغاً صحيحاً أكبر من صفر';
                    }
                    if (n > 99999) {
                      return 'المبلغ يتجاوز الحد الأقصى (99,999)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // حقل الملاحظات
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.charcoal,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات وتفاصيل (اختياري)',
                    prefixIcon: Icon(Icons.note_outlined, color: AppColors.charcoal),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),

                // زر التأكيد
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.charcoal.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSubmitting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            else ...[
                              const Icon(Icons.check_rounded, size: 22, color: Colors.white),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isSubmitting ? 'جاري الإيداع...' : 'تأكيد',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
