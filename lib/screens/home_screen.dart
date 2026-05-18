import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../gamification/gamification_dialogs.dart';
import '../providers/savings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/deposit_dialog.dart';
import '../widgets/savings_grid.dart';
import '../widgets/streak_card.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';

/// Home screen designed to mirror the physical sticker layout:
/// a house-shaped card with the 100-day grid inside, decorative
/// background arcs, brand header, and "Save for" goal section.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasPendingQuest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run after first frame so context is ready for dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGamification();
      final provider = context.read<SavingsProvider>();
      NotificationService().scheduleDailyNotifications(provider.completedDays);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final provider = context.read<SavingsProvider>();
      NotificationService().scheduleDailyNotifications(provider.completedDays);
    }
  }

  Future<void> _runGamification() async {
    if (!mounted) return;
    final provider = context.read<SavingsProvider>();

    // 1. Check Streak Protection first
    if (provider.isStreakBroken) {
      await showLifebuoyDialog(context);
    }
    if (!mounted) return;

    final days = provider.completedDays;

    // Show milestone first (highest priority), then quest, then insight
    await checkAndShowMilestone(context, days);
    if (!mounted) return;
    await checkAndShowWeeklyQuest(context, days);
    if (!mounted) return;
    // await checkAndShowDailyInsight(context);
    // if (!mounted) return;

    _refreshPendingQuestBadge();
  }

  Future<void> _refreshPendingQuestBadge() async {
    final pending = await hasPendingQuest();
    if (mounted) setState(() => _hasPendingQuest = pending);
  }

  void _showTestNotificationsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Test Notifications (3s delay)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wb_sunny),
                title: const Text('Morning Habit'),
                onTap: () {
                  Navigator.pop(ctx);
                  NotificationService().testNotification(
                      'صباح الإنجاز! ☀️', 'صباح الخير! وفرت ثمن قهوة اليوم؟ حطها بالحصالة وخلي بداية يومك إنجاز ☕');
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Evening Escalation'),
                onTap: () {
                  Navigator.pop(ctx);
                  NotificationService().testNotification(
                      'تنبيه! ⚠️', 'الستريك تبعك في خطر! 🔥 لا تضيع تعب الأيام الماضية، سجل إيداعك الآن.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.weekend),
                title: const Text('Weekend Context'),
                onTap: () {
                  Navigator.pop(ctx);
                  NotificationService().testNotification(
                      'صباح الإنجاز! ☀️', 'الويكند بلّش والمصاريف رح تزيد! ادفع لحصالتك أولاً قبل ما تطير الفلوس.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.rocket_launch),
                title: const Text('Milestone Teaser'),
                onTap: () {
                  Navigator.pop(ctx);
                  NotificationService().testNotification(
                      'قربت توصل! 🚀', 'باقي يومين بس وتوصل لمحطة جديدة وتكسب مكافأتك! لا توقف هسا.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_dissatisfied),
                title: const Text('Passive-Aggressive'),
                onTap: () {
                  Navigator.pop(ctx);
                  NotificationService().testNotification(
                      'وينك؟ 🧐', 'يبدو أن تحقيق هدفك لم يعد من أولوياتك حالياً 😔. سنتوقف عن إرسال التذكيرات لك لبعض الوقت.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text('Developer Debug',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lightbulb_outline),
                        title: const Text('Test Daily Insight (Random)'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_insight_date');
                          if (!mounted) return;
                          await checkAndShowDailyInsight(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.flag_rounded),
                        title: const Text('Test Weekly Quest (Day 7)'),
                        subtitle: const Text('Coffee quest'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(7);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_quest_date');
                          if (!mounted) return;
                          await checkAndShowWeeklyQuest(context, 7);
                          _refreshPendingQuestBadge();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Test Weekly Quest (Day 14)'),
                        subtitle: const Text('Restaurant quest'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(14);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_quest_date');
                          if (!mounted) return;
                          await checkAndShowWeeklyQuest(context, 14);
                          _refreshPendingQuestBadge();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.celebration),
                        title: const Text('Test Milestone (Day 25)'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(25);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_milestone_shown');
                          if (!mounted) return;
                          await checkAndShowMilestone(context, 25);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.celebration),
                        title: const Text('Test Milestone (Day 50)'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(50);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_milestone_shown');
                          if (!mounted) return;
                          await checkAndShowMilestone(context, 50);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.celebration),
                        title: const Text('Test Milestone (Day 75)'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(75);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_milestone_shown');
                          if (!mounted) return;
                          await checkAndShowMilestone(context, 75);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.celebration),
                        title: const Text('Test Milestone (Day 100)'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugSetDays(100);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('last_milestone_shown');
                          if (!mounted) return;
                          await checkAndShowMilestone(context, 100);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.monetization_on, color: Colors.orange),
                        title: const Text('Add 500 Coins'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugAdd500Coins();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.refresh, color: Colors.green),
                        title: const Text('Reset Daily Limits'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugResetDailyLimits();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Reset All Data',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final provider = context.read<SavingsProvider>();
                          await provider.debugResetData();
                          _refreshPendingQuestBadge();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: const Text('Test Notifications Menu'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showTestNotificationsMenu(context);
                        },
                      ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final user = provider.userProfile;
    if (user == null) return const AuthScreen();

    return Scaffold(
      drawer: _AppDrawer(provider: provider),
      body: Stack(
        children: [
          const _BackgroundDecor(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Sticky App Bar ──
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TopBar(
                      provider: provider,
                      hasPendingQuest: _hasPendingQuest,
                      onQuestBadgeTap: () async {
                        await checkAndShowPendingQuest(context, provider.completedDays);
                        _refreshPendingQuestBadge();
                      },
                    ),
                  ),
                ),

                // ── Main content ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _HouseCard(user: user, provider: provider),
                      const SizedBox(height: 16),
                      const StreakCard(),
                      const SizedBox(height: 12),
                      _SummaryRow(provider: provider),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── FAB ──
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'debug_btn',
            backgroundColor: AppColors.charcoal,
            onPressed: () => _showDebugMenu(context),
            child: const Icon(Icons.bug_report, color: AppColors.white),
          ),
          const SizedBox(height: 16),
          if (!provider.isComplete)
            FloatingActionButton(
              heroTag: 'add_btn',
              onPressed: () async {
                await DepositDialog.show(context);
                _refreshPendingQuestBadge();
              },
              child: const Icon(Icons.add_rounded, size: 28),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top Bar — original layout preserved, pending quest badge added
// ═══════════════════════════════════════════════════════════════════════════════

// ─── App Drawer ───────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final SavingsProvider provider;
  const _AppDrawer({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Top safe area padding only
          const SafeArea(bottom: false, child: SizedBox.shrink()),
          // Menu Items
          _DrawerItem(
            icon: Icons.person_outline_rounded,
            label: 'الملف الشخصي',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.emoji_events_rounded,
            label: 'لوحة الصدارة',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
            },
          ),
          const Spacer(),
          const Divider(color: AppColors.borderLight, height: 1),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'تسجيل الخروج',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              provider.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
          const SafeArea(top: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color = AppColors.charcoal});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top Bar — hamburger + original layout
// ═══════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final SavingsProvider provider;
  final bool hasPendingQuest;
  final VoidCallback onQuestBadgeTap;

  const _TopBar({
    required this.provider,
    required this.hasPendingQuest,
    required this.onQuestBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Hamburger Menu ──
        GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Icon(Icons.menu_rounded, size: 20, color: AppColors.charcoal),
          ),
        ),
        const Spacer(),

        // ── Pending quest badge (new, non-breaking) ──
        if (hasPendingQuest)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'You have a pending quest!',
              child: GestureDetector(
                onTap: onQuestBadgeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Pending Quest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Coin Counter (clickable) ──
        GestureDetector(
          onTap: () => showWalletDialog(context),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.generating_tokens_rounded, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${provider.woodenCoins}',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        IconButton(
          onPressed: () {
            provider.signOut();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
          icon: const Icon(Icons.logout_rounded, size: 20),
          style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
          tooltip: 'Sign out',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// House-Shaped Sticker Card — original layout preserved
// ═══════════════════════════════════════════════════════════════════════════════

class _HouseCard extends StatelessWidget {
  final dynamic user;
  final SavingsProvider provider;

  const _HouseCard({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HouseClipper(),
      child: Container(
        color: AppColors.cardFill,
        child: Column(
          children: [
            const SizedBox(height: 48), // space for the roof peak
            // ── Brand Logo ──
            Image.asset(
              'assets/images/logo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),

            // ── 100-Day Grid ──
            const SavingsGrid(),
            const SizedBox(height: 20),

            // ── "Save for" section ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Left: Save for goal
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🎯 ', style: TextStyle(fontSize: 14)),
                              Text(
                                'Save for',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.borderLight,
                                  width: 1,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                            child: Text(
                              '${_formatNumber(user.financialGoal)} JOD',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right: progress box
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved so far',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${provider.totalSaved.toStringAsFixed(0)} JOD',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green,
                                ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: user.financialGoal > 0
                                  ? (provider.totalSaved / user.financialGoal)
                                        .clamp(0.0, 1.0)
                                  : 0,
                              minHeight: 4,
                              backgroundColor: AppColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// House Clipper — pentagon / envelope shape
// ═══════════════════════════════════════════════════════════════════════════════

class _HouseClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const roofHeight = 44.0;
    final path = Path()
      ..moveTo(0, roofHeight)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, roofHeight)
      ..lineTo(size.width, size.height - 12)
      ..quadraticBezierTo(size.width, size.height, size.width - 12, size.height)
      ..lineTo(12, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 12)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Background Decorative Arcs (matching sticker corners)
// ═══════════════════════════════════════════════════════════════════════════════

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DecorPainter(),
      size: MediaQuery.of(context).size,
    );
  }
}

class _DecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.decorArc.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Top-right arc
    canvas.drawCircle(Offset(size.width + 30, -30), 100, paint);

    // Bottom-left arc
    canvas.drawCircle(Offset(-30, size.height + 30), 100, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Summary Stats Row — original layout preserved
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryRow extends StatelessWidget {
  final SavingsProvider provider;
  const _SummaryRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
          label: 'Days',
          value: '${provider.completedDays}/100',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(width: 8),
        _StatBox(
          label: 'Deposits',
          value: '${provider.deposits.length}',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(width: 8),
        _StatBox(
          label: 'Remaining',
          value: '${provider.remainingDays}',
          icon: Icons.hourglass_empty_rounded,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
