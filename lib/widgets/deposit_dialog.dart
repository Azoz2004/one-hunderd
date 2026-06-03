import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gamification/gamification_dialogs.dart';
import '../providers/savings_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// A modal bottom sheet form for logging a daily deposit.
/// Supports multiple deposits per day.
class DepositDialog extends StatefulWidget {
  const DepositDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DepositDialog(),
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
    // Suggest the next day's expected amount (day N = N JD)
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

    setState(() {
      _isSubmitting = true;
    });

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
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Capture updated state BEFORE closing
    final updatedDays = provider.completedDays;
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();

    // Notification Logic
    final notificationService = NotificationService();
    await notificationService.cancelEveningNotification();
    await notificationService.schedulePassiveAggressiveReminder();

    // Trigger gamification after the sheet closes
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
    final todayDeposits = provider.todayDeposits;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
        
              // العنوان
              Text(
                'تسجيل إيداع',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              if (todayDeposits.isNotEmpty)
                Text(
                  todayDeposits.length == 1
                      ? 'إيداع واحد اليوم — ${provider.todayTotal.toStringAsFixed(1)} JD'
                      : '${todayDeposits.length} إيداعات اليوم — ${provider.todayTotal.toStringAsFixed(1)} JD',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                )
              else
                Text(
                  'اليوم ${provider.completedDays + 1} من 100',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 24),
        
              // حقل المبلغ
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                maxLength: 5,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (JD)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  prefixIcon: Icon(Icons.note_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
        
              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (provider.isComplete || _isSubmitting) ? null : _save,
                  icon: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    provider.isComplete ? 'أحسنت! أتممت التحدي 🏆' : (_isSubmitting ? 'جاري الإيداع...' : 'تسجيل الإيداع'),
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
