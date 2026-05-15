import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final dayTotal = provider.totalForDay(dayNumber);

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
                      'Day $dayNumber',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                    if (calendarDate != null)
                      Text(
                        dateFormat.format(calendarDate),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${dayTotal.toStringAsFixed(1)} JOD',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Deposits list
            Text(
              '${deposits.length} deposit${deposits.length > 1 ? 's' : ''} this day',
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
                                '${dep.amount.toStringAsFixed(1)} JOD',
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
                        Text(
                          timeFormat.format(dep.date),
                          style: Theme.of(ctx).textTheme.bodySmall,
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
}
