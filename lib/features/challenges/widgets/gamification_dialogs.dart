import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';

// ─── SharedPrefs Keys ────────────────────────────────────────────────────────
const _kLastInsightDate = 'last_insight_date';
const _kLastQuestDate = 'last_quest_date';
const _kQuestAccepted = 'quest_accepted_day';
const _kQuestDone = 'quest_done_day';
const _kLastMilestoneShown = 'last_milestone_shown';

// ─── Daily Insight Data ──────────────────────────────────────────────────────
const List<Map<String, String>> _insights = [
  {
    'quote':
        'الادخار ليس ما تبقى بعد الإنفاق، بل الإنفاق هو ما يتبقى بعد الادخار.',
    'author': 'وارن بافيت',
  },
  {
    'quote': 'لا تؤجّل ما يمكن ادخاره اليوم إلى الغد؛ فالوقت أثمن من الذهب.',
    'author': 'حكمة مالية',
  },
  {
    'quote': 'كلّ دينار تدّخره اليوم هو خطوة نحو حريّتك المالية غداً.',
    'author': 'تحدي المئة',
  },
  {
    'quote': 'الثروة تُبنى قطرةً قطرة، فلا تستهن بالقليل.',
    'author': 'حكمة مالية',
  },
  {
    'quote': 'الإنسان الحكيم لا ينفق كلّ ما يملك، بل يوفّر دائماً للمستقبل.',
    'author': 'أرسطو',
  },
  {
    'quote': 'ميزانيتك هي خطّة لمستقبلك؛ كلّ دينار يحمل نيّة.',
    'author': 'ديف رامسي',
  },
  {
    'quote': 'الاستقلال المالي لا يأتي بالصدفة، بل بالانضباط والاتساق.',
    'author': 'تحدي المئة',
  },
];

// ─── Weekly Quest Data ────────────────────────────────────────────────────────
const List<Map<String, String>> _quests = [
  {
    'title': 'يوم بدون قهوة خارجية ☕',
    'desc': 'تحدَّ نفسك اليوم وأعِدّ قهوتك في المنزل. وفّر ما كنت ستنفقه.',
  },
  {
    'title': 'يوم بدون مطاعم 🍽️',
    'desc': 'تجنّب الطلب من الخارج اليوم وأعِدّ وجبتك بنفسك.',
  },
  {
    'title': 'مراجعة مصاريفك الأسبوعية 📊',
    'desc':
        'خصّص 10 دقائق لمراجعة ما أنفقته هذا الأسبوع واكتشف أين يمكن التوفير.',
  },
  {
    'title': 'تحدّي "لا شراء اليوم" 🚫',
    'desc': 'لا تشترِ أي شيء غير ضروري اليوم. التحدي يبدأ الآن!',
  },
  {
    'title': 'إلغاء اشتراك غير مستخدَم 📱',
    'desc': 'ابحث عن اشتراك رقمي لا تستخدمه وألغِه الآن.',
  },
  {
    'title': 'يوم بدون تسوّق إلكتروني 🛒',
    'desc': 'أغلِق تطبيقات التسوّق ليوم واحد كامل.',
  },
  {
    'title': 'ادّخر مضاعفَ اليوم 💰',
    'desc': 'إضافةً لإيداع اليوم، ضاعِف المبلغ واحتفل بتقدّمك!',
  },
];

// ─── Milestone Data ───────────────────────────────────────────────────────────
const Map<int, Map<String, String>> _milestones = {
  25: {
    'title': 'أنت الآن 25% هناك! 🎉',
    'body': 'ربع الرحلة خلف ظهرك! الاتساق هو سرّ نجاحك.',
  },
  50: {
    'title': 'منتصف الطريق! 🏅',
    'body': 'وصلت إلى اليوم 50 — نصف التحدي أُنجِز. استمرّ!',
  },
  75: {
    'title': 'ثلاثة أرباع المسافة! 🌟',
    'body': 'اليوم 75 — لا تتوقف الآن، النهاية قريبة جداً!',
  },
  100: {
    'title': 'أنجزت التحدي! 🏆',
    'body': 'مبروك! أكملت 100 يوم من الادخار الانضباطي. أنت بطل!',
  },
};

// ════════════════════════════════════════════════════════════════════════════════
// Public API — call these from HomeScreen / DepositDialog
// ════════════════════════════════════════════════════════════════════════════════

/// Checks and shows the Daily Insight if not yet shown today.
Future<void> checkAndShowDailyInsight(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final today = _todayKey();
  final last = prefs.getString(_kLastInsightDate) ?? '';
  if (last == today) return;
  if (!context.mounted) return;
  await prefs.setString(_kLastInsightDate, today);
  if (!context.mounted) return;
  await _showInsightDialog(context);
}

/// Checks and shows the Weekly Quest if day is a multiple of 7.
Future<void> checkAndShowWeeklyQuest(
  BuildContext context,
  int completedDays,
) async {
  if (completedDays == 0 || completedDays % 7 != 0) return;
  final prefs = await SharedPreferences.getInstance();
  final lastQuestDate = prefs.getString(_kLastQuestDate) ?? '';
  final today = _todayKey();
  if (lastQuestDate == today) return;
  if (!context.mounted) return;
  await prefs.setString(_kLastQuestDate, today);
  if (!context.mounted) return;
  await _showQuestDialog(context, completedDays, prefs);
}

/// Checks and shows Milestone dialog for day 25/50/75/100.
Future<void> checkAndShowMilestone(
  BuildContext context,
  int completedDays,
) async {
  if (!_milestones.containsKey(completedDays)) return;
  final prefs = await SharedPreferences.getInstance();
  final lastShown = prefs.getInt(_kLastMilestoneShown) ?? 0;
  if (lastShown >= completedDays) return;
  await prefs.setInt(_kLastMilestoneShown, completedDays);
  if (!context.mounted) return;
  await _showMilestoneDialog(context, completedDays);
}

/// Checks if there is a pending quest that has been accepted but not completed.
Future<bool> hasPendingQuest() async {
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getInt(_kQuestAccepted);
  final done = prefs.getInt(_kQuestDone);
  return accepted != null && accepted != done;
}

/// Shows the pending quest dialog if one exists.
Future<void> checkAndShowPendingQuest(BuildContext context, int completedDays) async {
  final prefs = await SharedPreferences.getInstance();
  final acceptedDay = prefs.getInt(_kQuestAccepted);
  final doneDay = prefs.getInt(_kQuestDone);

  if (acceptedDay != null && acceptedDay != doneDay) {
    if (!context.mounted) return;
    await _showQuestDialog(context, acceptedDay, prefs);
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 1 — Daily Insight Dialog
// ════════════════════════════════════════════════════════════════════════════════

Future<void> _showInsightDialog(BuildContext context) async {
  final insight = _insights[Random().nextInt(_insights.length)];

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 34,
                color: Color(0xFFD4A017),
              ),
            ),
            const SizedBox(height: 20),

            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'النصيحة اليومية',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quote
            Text(
              '"${insight['quote']}"',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 10),

            // Author
            Text(
              '— ${insight['author']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // Divider
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 20),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('رائع، شكراً!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

// ════════════════════════════════════════════════════════════════════════════════
// 2 — Weekly Quest Dialog
// ════════════════════════════════════════════════════════════════════════════════

Future<void> _showQuestDialog(
  BuildContext context,
  int day,
  SharedPreferences prefs,
) async {
  final questIndex = ((day ~/ 7) - 1) % _quests.length;
  final quest = _quests[questIndex];

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final accepted = prefs.getInt(_kQuestAccepted) == day;
        final done = prefs.getInt(_kQuestDone) == day;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Icon badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),

                // Label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFF3E8FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'المهمة الأسبوعية 🎯',
                    style: TextStyle(
                      color: Color(0xFF667EEA),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  quest['title']!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  quest['desc']!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Completion badge
                if (done)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'أنجزت المهمة! 🎉',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (accepted) ...[
                  // Mark as Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await prefs.setInt(_kQuestDone, day);
                        setState(() {});
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('أنجزت المهمة! ✅'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'لاحقاً',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ] else ...[
                  // Accept / Skip buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await prefs.setInt(_kQuestAccepted, day);
                        setState(() {});
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                      label: const Text('قبول المهمة!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderLight),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('تخطّي'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        );
      },
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// 3 — Milestone Celebration Dialog  (with confetti)
// ════════════════════════════════════════════════════════════════════════════════

Future<void> _showMilestoneDialog(BuildContext context, int day) async {
  final milestone = _milestones[day]!;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MilestoneDialogContent(
      day: day,
      title: milestone['title']!,
      body: milestone['body']!,
    ),
  );
}

class _MilestoneDialogContent extends StatefulWidget {
  final int day;
  final String title;
  final String body;

  const _MilestoneDialogContent({
    required this.day,
    required this.title,
    required this.body,
  });

  @override
  State<_MilestoneDialogContent> createState() =>
      _MilestoneDialogContentState();
}

class _MilestoneDialogContentState extends State<_MilestoneDialogContent> {
  late final ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  static const Map<int, Color> _milestoneColors = {
    25: Color(0xFFFF9F43),
    50: Color(0xFF667EEA),
    75: Color(0xFF11D6A1),
    100: Color(0xFFFFD700),
  };

  static const Map<int, IconData> _milestoneIcons = {
    25: Icons.star_outline_rounded,
    50: Icons.military_tech_rounded,
    75: Icons.emoji_events_outlined,
    100: Icons.workspace_premium_rounded,
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    // Start confetti after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _milestoneColors[widget.day] ?? AppColors.green;
    final icon = _milestoneIcons[widget.day] ?? Icons.star_rounded;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti cannon — fires from top center
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 30,
          gravity: 0.2,
          emissionFrequency: 0.05,
          colors: const [
            Color(0xFFFF9F43),
            Color(0xFF667EEA),
            Color(0xFF11D6A1),
            Color(0xFFFFD700),
            Color(0xFFFF6B6B),
          ],
        ),

        // Dialog
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 38, color: color),
                ),
                const SizedBox(height: 20),

                // Day badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'اليوم ${widget.day}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Body
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 20),

                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : () => _shareAchievement(context, color),
                    icon: _isSharing 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(_isSharing ? 'جاري التحضير...' : 'مشاركة الإنجاز'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'استمرّ في التحدي 💪',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareAchievement(BuildContext context, Color color) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final provider = context.read<SavingsProvider>();
      final totalSaved = provider.totalSaved;
      final date = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      // Capture widget off-screen
      final imageBytes = await _screenshotController.captureFromWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/logo.png', width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'اليوم ${widget.day} من 100',
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'المبلغ المدخر',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${totalSaved.toStringAsFixed(2)} JD',
                          style: const TextStyle(color: AppColors.green, fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        '#تحدي_المئة_يوم',
                        style: TextStyle(color: Color(0xFF667EEA), fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/achievement_${widget.day}.png');
      await file.writeAsBytes(imageBytes);

      final xfile = XFile(file.path);
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
          text: 'لقد حققت إنجازاً جديداً في تحدي المئة يوم! 🎉\nوصلت إلى اليوم ${widget.day} وادخرت ${totalSaved.toStringAsFixed(2)} JD.\nهل أنت جاهز للتحدي؟ #تحدي_المئة_يوم',
        ),
      );

      if (!context.mounted) return;
      
      if (result.status == ShareResultStatus.success) {
        final success = await provider.registerShareReward();
        if (!context.mounted) return;
        if (success) {
          AppSnackbar.show(
            context: context,
            message: 'تمت المشاركة بنجاح! حصلت على 20 قطعة خشبية 🪙',
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context: context,
        message: 'حدث خطأ أثناء المشاركة: $e',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// ─── Lifebuoy System ──────────────────────────────────────────────────────────

Future<void> showLifebuoyDialog(BuildContext context, {bool manualTrigger = false}) async {
  final provider = context.read<SavingsProvider>();
  
  if (manualTrigger && !provider.isStreakBroken) {
    AppSnackbar.show(
      context: context,
      message: 'الستريك الخاص بك بأمان حالياً! 🔥 لا تحتاج لاستخدام طوق نجاة.',
      isSuccess: false,
      isInfo: true,
    );
    if (provider.lifebuoys > 0) return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final hasLifebuoy = provider.lifebuoys > 0;
      
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support, size: 64, color: Colors.deepOrangeAccent),
                const SizedBox(height: 16),
                Text(
                  hasLifebuoy ? 'إنقاذ الستريك!' : 'نفذت أطواق النجاة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasLifebuoy
                      ? 'هل تريد استخدام طوق نجاة لإنقاذ الستريك؟'
                      : 'ليس لديك أطواق نجاة. هل تريد شراء طوق مقابل 1000 قطعة خشبية؟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                if (hasLifebuoy)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (!manualTrigger) {
                              await provider.resetStreak();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: AppColors.borderLight),
                          ),
                          child: const Text(
                            'لا، شكراً',
                            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await provider.useLifebuoy();
                            if (context.mounted) {
                              AppSnackbar.show(
                                context: context,
                                message: 'تم إنقاذ الستريك بنجاح! 🛟',
                                isSuccess: true,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrangeAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('استخدام الطوق', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (!manualTrigger) {
                              await provider.resetStreak();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: AppColors.borderLight),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            try {
                              await provider.buyLifebuoy();
                              if (!manualTrigger) {
                                await provider.useLifebuoy();
                                if (context.mounted) {
                                  AppSnackbar.show(
                                    context: context,
                                    message: 'تم شراء طوق نجاة واستخدامه لإنقاذ الستريك! 🛟🔥',
                                    isSuccess: true,
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  AppSnackbar.show(
                                    context: context,
                                    message: 'تم شراء طوق نجاة بنجاح! 🛟',
                                    isSuccess: true,
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackbar.show(
                                  context: context,
                                  message: e.toString().replaceAll('Exception: ', ''),
                                  isSuccess: false,
                                );
                              }
                              if (!manualTrigger) {
                                await provider.resetStreak();
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.charcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('شراء الطوق', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ─── Wallet System ────────────────────────────────────────────────────────────

Future<void> showWalletDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final provider = context.watch<SavingsProvider>();
          final today = DateTime.now();
          final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final canClaimDaily = provider.lastDailyClaimDate != todayStr;
          final adsWatched = provider.adsWatchedToday;
          final canWatchAd = adsWatched < 4;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: AppColors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 64, color: AppColors.charcoal),
                  const SizedBox(height: 16),
                  const Text(
                    'المحفظة',
                    style: TextStyle(color: AppColors.charcoal, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رصيدك الحالي: ${provider.woodenCoins} قطعة خشبية',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  
                  // Daily Claim
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canClaimDaily
                          ? () async {
                              await provider.claimDailyReward();
                              if (ctx.mounted) {
                                AppSnackbar.show(
                                  context: ctx,
                                  message: 'حصلت على 10 قطع خشبية! 🪙',
                                  isSuccess: true,
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                      label: Text(canClaimDaily ? 'المكافأة اليومية (+10)' : 'تم الاستلام اليوم', style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.borderLight,
                        disabledForegroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Watch Ad
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: canWatchAd
                          ? () async {
                              // Simulate ad viewing
                              showDialog(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.charcoal)),
                              );
                              await Future.delayed(const Duration(seconds: 2));
                              if (ctx.mounted) Navigator.pop(ctx); // Close loading
                              
                              await provider.watchAdReward();
                              if (ctx.mounted) {
                                AppSnackbar.show(
                                  context: ctx,
                                  message: 'حصلت على 25 قطعة خشبية! 🪙',
                                  isSuccess: true,
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                      label: Text('شاهد إعلان (+25)   $adsWatched/4', style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      );
    },
  );
}
