import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/savings_provider.dart';
import '../theme/app_theme.dart';

/// A minimal streak display matching the sticker aesthetic.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final streak = provider.currentStreak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          // Streak number
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$streak',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥  Day Streak',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 0
                      ? 'Make your first deposit today!'
                      : 'Keep it going!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Today indicator
          if (provider.hasTodayDeposit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '✓ Today',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
