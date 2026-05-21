import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/savings_provider.dart';
import '../theme/app_theme.dart';

/// A single cell in the 100-day grid, matching the physical sticker aesthetic.
///
/// Unpaid: thin-bordered circle with day number.
/// Paid: green circle with white checkmark.
/// Tapping a paid cell shows a bottom sheet listing all deposits for that day.
class DayCell extends StatelessWidget {
  final int dayNumber;

  const DayCell({super.key, required this.dayNumber});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final completed = provider.isDayCompleted(dayNumber);

    return GestureDetector(
      onTap: completed ? () => _showDetails(context, provider) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: completed ? AppColors.green : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: completed ? AppColors.green : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Center(
          child: completed
              ? const Icon(Icons.check_rounded, color: AppColors.white, size: 14)
              : Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, SavingsProvider provider) {
    final deposits = provider.getDepositsForDay(dayNumber);
    final calendarDate = provider.getDateForDay(dayNumber);
    final dayTotal = provider.totalForDay(dayNumber);

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
                      'اليوم $dayNumber',
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
                  '${dayTotal.toStringAsFixed(1)} JD',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
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
                              Text(
                                '${dep.amount.toStringAsFixed(1)} JD',
                                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
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
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
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
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
