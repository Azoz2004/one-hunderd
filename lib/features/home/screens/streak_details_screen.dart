import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

/// صفحة تفاصيل الستريك — تقويم يومي بأسلوب Duolingo + إحصائيات الالتزام.
class StreakDetailsScreen extends StatefulWidget {
  const StreakDetailsScreen({super.key});

  @override
  State<StreakDetailsScreen> createState() => _StreakDetailsScreenState();
}

class _StreakDetailsScreenState extends State<StreakDetailsScreen> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (_displayedMonth.isBefore(currentMonth)) {
      setState(() {
        _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
      });
    }
  }

  // اسم الشهر بالعربية
  String _monthName(int month) {
    const names = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final depositDays = provider.depositDays;
    final protectedDays = provider.protectedDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonth = DateTime(now.year, now.month);
    final isCurrentMonth = _displayedMonth == currentMonth;

    final streak = provider.currentStreak;
    final longest = provider.longestStreak;
    final rate = provider.commitmentRate;
    final totalCommitted = depositDays.length;

    // رسالة تحفيزية
    String motivationalMsg;
    if (streak == 0) {
      motivationalMsg = 'ابدأ من جديد — كل بطل بدأ من الصفر 💪';
    } else if (streak >= longest && longest > 0) {
      motivationalMsg = 'أنت الآن عند أفضل مسيرتك التاريخية! 🏆';
    } else {
      final diff = longest - streak;
      motivationalMsg = diff == 1
          ? 'يوم واحد لكسر رقمك القياسي! 🔥'
          : '$diff أيام لكسر رقمك القياسي! 🔥';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6EFE6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6EFE6),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'تفاصيل الالتزام',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.charcoal, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── التقويم الشهري ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // شريط التنقل بين الأشهر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.charcoal),
                        ),
                        Text(
                          '${_monthName(_displayedMonth.month)} ${_displayedMonth.year}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                        IconButton(
                          onPressed: isCurrentMonth ? null : _nextMonth,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: isCurrentMonth
                                ? AppColors.charcoal.withValues(alpha: 0.3)
                                : AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // رأس الأيام
                    const _WeekdayHeader(),
                    const SizedBox(height: 8),

                    // أيام الشهر
                    _MonthCalendar(
                      month: _displayedMonth,
                      today: today,
                      depositDays: depositDays,
                      protectedDays: protectedDays,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── مفتاح الألوان ───────────────────────────────────────────
              _LegendRow(),
              const SizedBox(height: 24),

              // ─── بطاقات الإحصائيات ───────────────────────────────────────
              _StatsRow(
                streak: streak,
                longest: longest,
                rate: rate,
                totalCommitted: totalCommitted,
              ),
              const SizedBox(height: 20),


              // ─── الرسالة التحفيزية ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.charcoal.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  motivationalMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
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

// ─── بطاقات الإحصائيات الأربع ────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int streak;
  final int longest;
  final double rate;
  final int totalCommitted;

  const _StatsRow({
    required this.streak,
    required this.longest,
    required this.rate,
    required this.totalCommitted,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).round();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(icon: Icons.local_fire_department_rounded, value: '$streak', label: 'الستريك الحالي', color: const Color(0xFFE07820)),
        _StatCard(icon: Icons.emoji_events_rounded, value: '$longest', label: 'أطول ستريك', color: const Color(0xFF8B6914)),
        _StatCard(icon: Icons.pie_chart_rounded, value: '$pct%', label: 'نسبة الالتزام', color: AppColors.green),
        _StatCard(icon: Icons.calendar_month_rounded, value: '$totalCommitted', label: 'أيام الالتزام', color: const Color(0xFF4A6FA5)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // دائرة الأيقونة الملونة
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          // القيمة والوصف
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── رأس أيام الأسبوع ────────────────────────────────────────────────────────
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    // الأسبوع يبدأ من الأحد
    const days = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
    return Row(
      children: days
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── شبكة أيام الشهر ─────────────────────────────────────────────────────────
class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Set<DateTime> depositDays;
  final Set<DateTime> protectedDays;

  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.depositDays,
    required this.protectedDays,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // يوم البداية (0=الأحد ... 6=السبت)
    final startWeekday = firstDay.weekday % 7; // Flutter: Mon=1, Sun=7→0

    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIdx) {
        return Row(
          children: List.generate(7, (colIdx) {
            final cellIndex = rowIdx * 7 + colIdx;
            final dayNum = cellIndex - startWeekday + 1;

            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 40));
            }

            final dayDate = DateTime(month.year, month.month, dayNum);
            final isToday = dayDate == today;
            final isPast = dayDate.isBefore(today);
            final isFuture = dayDate.isAfter(today);
            final hasDeposit = depositDays.contains(dayDate);
            final isProtected = protectedDays.contains(dayDate);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _DayCell(
                  day: dayNum,
                  isToday: isToday,
                  isPast: isPast,
                  isFuture: isFuture,
                  hasDeposit: hasDeposit,
                  isProtected: isProtected,
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isPast;
  final bool isFuture;
  final bool hasDeposit;
  final bool isProtected;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.isFuture,
    required this.hasDeposit,
    required this.isProtected,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = AppColors.charcoal.withValues(alpha: 0.25);
    } else if (hasDeposit) {
      bgColor = AppColors.green.withValues(alpha: 0.85);
      textColor = Colors.white;
    } else if (isProtected) {
      bgColor = Colors.deepOrangeAccent.withValues(alpha: 0.85);
      textColor = Colors.white;
    } else if (isPast) {
      bgColor = AppColors.charcoal.withValues(alpha: 0.07);
      textColor = AppColors.charcoal.withValues(alpha: 0.45);
    } else {
      // today without deposit
      bgColor = Colors.transparent;
      textColor = AppColors.charcoal;
    }

    if (isToday) {
      border = Border.all(
        color: hasDeposit
            ? AppColors.green
            : (isProtected ? Colors.deepOrangeAccent : const Color(0xFFE07820)),
        width: 2,
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: hasDeposit || isProtected || isToday ? FontWeight.w800 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

// ─── مفتاح الألوان ────────────────────────────────────────────────────────────
class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: AppColors.green, label: 'التزام'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.deepOrangeAccent.withValues(alpha: 0.85), label: 'طوق نجاة'),
        const SizedBox(width: 16),
        _LegendItem(color: AppColors.charcoal.withValues(alpha: 0.15), label: 'بدون إيداع'),
        const SizedBox(width: 16),
        _LegendItem(
          color: Colors.transparent,
          label: 'اليوم',
          borderColor: const Color(0xFFE07820),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color? borderColor;

  const _LegendItem({required this.color, required this.label, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
