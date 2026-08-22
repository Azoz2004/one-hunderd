import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_hunderd/features/challenges/widgets/gamification_dialogs.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:one_hunderd/core/widgets/deposit_dialog.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/core/widgets/savings_grid.dart';
import 'package:one_hunderd/core/widgets/streak_card.dart';
import 'package:one_hunderd/core/services/notification_service.dart';
import 'package:one_hunderd/features/challenges/services/challenge_service.dart';
import 'package:one_hunderd/features/auth/screens/auth_screen.dart';
import 'package:one_hunderd/features/activities/screens/activity_log_screen.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart';
import 'package:one_hunderd/features/settings/screens/settings_screen.dart';
import 'package:one_hunderd/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:one_hunderd/features/friends/screens/friends_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_hub_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_details_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_competitive_screen.dart';

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
  // Prevent duplicate separation dialogs from being shown
  bool _hasSeparationDialogShown = false;
  bool _hasDissolvedDialogShown = false;
  bool _hasNewSessionDialogShown = false;
  bool _hasPokeDialogShown = false;
  int _gridAnimationTrigger = 0;

  Future<T?> _pushScreen<T>(Widget screen) async {
    // 1. لا نقوم بأي إعادة بناء فورية لحظة الدفع لنحافظ على سلاسة انيميشن الصعود (380ms)
    // بعد اكتمال صعود الصفحة وتغطيتها للشاشة (450ms)، نطفئ الخلايا في الخلفية بهدوء
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() {
          if (_gridAnimationTrigger % 2 == 0) {
            _gridAnimationTrigger++;
          }
        });
      }
    });

    // 2. فتح الصفحة بحركة صعود ناعمة 60fps
    final result = await Navigator.push<T>(
      context,
      AppScalePageRoute<T>(page: screen),
    );

    // 3. عند العودة: ننتظر انتهاء انيميشن نزول وخروج الصفحة بالكامل (460ms)
    // وحينها تكون خلايا الشاشة الرئيسية مطفأة مسبقاً، فتبدأ موجة الامتلاء والإضاءة
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 480), () {
        if (mounted) {
          setState(() {
            if (_gridAnimationTrigger % 2 != 0) {
              _gridAnimationTrigger++;
            } else {
              _gridAnimationTrigger += 2;
            }
          });
        }
      });
    }
    return result;
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run after first frame so context is ready for dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGamification();
      final provider = context.read<SavingsProvider>();
      NotificationService().scheduleDailyNotifications(provider.completedDays);
      // Attach separation state listener
      provider.addListener(_onProviderChange);
    });
  }

  @override
  void dispose() {
    // Remove separation listener
    if (mounted) {
      context.read<SavingsProvider>().removeListener(_onProviderChange);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called whenever the SavingsProvider notifies listeners.
  /// Handles real-time separation request events.
  void _onProviderChange() {
    if (!mounted) return;
    final provider = context.read<SavingsProvider>();

    // ── Case 1: Session was dissolved (works for both cooperative AND competitive)
    if (provider.isSessionDissolved &&
        !_hasDissolvedDialogShown) {
      _hasDissolvedDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSessionDissolvedDialog();
      });
      return;
    }

    // ── Case 1.5: A new session started! (Receiver accepted)
    if (provider.hasNewSession && !_hasNewSessionDialogShown) {
      _hasNewSessionDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNewSessionStartedDialog();
      });
      return;
    }

    // ── Case 2: The partner wants to separate (works for both cooperative AND competitive)
    if ((provider.isCooperativeMode || provider.isCompetitiveMode) &&
        provider.hasPartnerRequestedSeparation &&
        !_hasSeparationDialogShown) {
      _hasSeparationDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPartnerRequestedSeparationDialog();
      });
      return;
    }

    // ── Reset flags when the separation request is cancelled/cleared
    if (!provider.hasPartnerRequestedSeparation) {
      _hasSeparationDialogShown = false;
    }
    if (!provider.isSessionDissolved) {
      _hasDissolvedDialogShown = false;
    }
    if (!provider.hasNewSession) {
      _hasNewSessionDialogShown = false;
    }

    // ── Case 4: Competitive poke notification ──────────────────────────
    if (provider.pendingPokeNotification && !_hasPokeDialogShown) {
      _hasPokeDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPokeBanner();
      });
      return;
    }
    if (!provider.pendingPokeNotification) {
      _hasPokeDialogShown = false;
    }
  }

  /// Shows a fun poke notification dialog when the competitive partner pokes you.
  void _showPokeBanner() {
    if (!mounted) return;
    final provider = context.read<SavingsProvider>();
    final pokedBy = provider.lastPokedBy ?? 'الخصم';
    provider.clearPokeNotification();
    showAppDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFF3E0),
          title: const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFFD84315), size: 28),
              SizedBox(width: 8),
              Text('لكزك خصمك!',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color(0xFFD84315))),
            ],
          ),
          content: Text(
            'نكزك $pokedBy ليذكّرك بالإيداع اليومي!\nلا تدعه يتقدم عليك',
            style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4E342E)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('حسناً',
                  style: TextStyle(
                      color: Color(0xFFFF5722), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog when a new session is established.
  void _showNewSessionStartedDialog() {
    final provider = context.read<SavingsProvider>();
    final type = provider.newSessionType ?? 'تعاوني';
    final isComp = type == 'تنافسي';

    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isComp ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
          title: Row(
            children: [
              Icon(
                isComp ? Icons.bolt_rounded : Icons.handshake_rounded,
                color: isComp ? const Color(0xFFFF5722) : const Color(0xFF2E7D32),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComp ? 'بدأ التحدي التنافسي!' : 'بدأ التحدي التعاوني!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: isComp ? const Color(0xFFD84315) : const Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isComp
                ? 'تم قبول دعوة التحدي التنافسي بنجاح! سيتم إغلاق التطبيق الآن لتهيئة البيانات المشتركة مع منافسك بشكل سليم.'
                : 'تم قبول دعوة التحدي التعاوني بنجاح! سيتم إغلاق التطبيق الآن لتهيئة البيانات المشتركة مع شريكك بشكل سليم.',
            style: TextStyle(
              fontSize: 14,
              color: isComp ? const Color(0xFFD84315) : const Color(0xFF2E7D32),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                exit(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isComp ? const Color(0xFFFF5722) : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'إغلاق التطبيق وبدء التحدي',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to the RECEIVING partner asking them to approve or reject.
  void _showPartnerRequestedSeparationDialog() {
    final provider = context.read<SavingsProvider>();
    final partnerName = provider.partnerName ?? 'شريكك';
    final isCompetitive = provider.isCompetitiveMode;

    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFF8E1),
          title: Row(
            children: [
              const Icon(Icons.link_off_rounded, color: Color(0xFFE65100), size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCompetitive ? 'طلب إنهاء من خصمك' : 'طلب انفصال من شريكك',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFF4E342E),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCompetitive
                    ? 'طلب $partnerName إنهاء التحدي التنافسي والعودة إلى النظام الفردي.'
                    : 'طلب $partnerName الانفصال عن التحدي التعاوني المشترك والعودة إلى النظام الفردي.',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'إذا وافقت، سيحدث التالي:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompetitive
                    ? '• يحتفظ كل لاعب بإيداعاته وستريكه ومسكوكاته بشكل مستقل.\n• يتحوّل نوع التحدي لكلا الطرفين إلى تحدٍّ فردي.\n• سيتم إغلاق التطبيق لكلا الطرفين لتحديث البيانات.'
                    : '• يحتفظ كل شريك بإيداعاته الفردية فقط.\n• يُعاد حساب ستريك الالتزام لكل شريك بشكل منفصل.\n• تُقسَّم المسكوكات وأطواق النجاة بالتساوي 50/50.\n• يتحوّل نوع التحدي لكلا الطرفين إلى تحدٍّ فردي.\n• سيتم إغلاق التطبيق لكلا الطرفين لتحديث البيانات.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D4C41),
                  height: 1.6,
                ),
              ),
            ],
          ),
          actions: [
            // Reject: continue the challenge
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _hasSeparationDialogShown = false;
                try {
                  await context.read<SavingsProvider>().rejectSeparation();
                  if (mounted) {
                    AppSnackbar.show(
                      context: context,
                      message: 'رفضت طلب الانفصال. يستمر التحدي المشترك!',
                      isSuccess: true,
                    );
                  }
                } catch (_) {}
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              child: const Text(
                'الاستمرار في التحدي 💪',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            // Approve: show second confirmation
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showApproveSeparationConfirmationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              child: const Text(
                'الموافقة على الانفصال',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Double-confirmation before actually completing the separation (receiver side).
  void _showApproveSeparationConfirmationDialog() {
    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFEBEE),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تأكيد الموافقة النهائية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هذا القرار لا يمكن التراجع عنه.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFFB71C1C),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'عند تأكيدك، سيتم تقسيم البيانات فوراً وسيُغلق التطبيق على جهازك وجهاز شريكك لإعادة تشغيل نظيف بالبيانات الفردية الجديدة.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFC62828),
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Go back to show the first dialog again
                _hasSeparationDialogShown = false;
                _showPartnerRequestedSeparationDialog();
              },
              child: const Text(
                'رجوع',
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = context.read<SavingsProvider>();
                Navigator.pop(ctx);
                try {
                  await provider.approveSeparation();
                } catch (e) {
                  debugPrint('approveSeparation error: $e');
                }
                // Always exit for a clean state reload
                exit(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'تأكيد الانفصال وإغلاق التطبيق',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to the INITIATOR when their partner has approved the dissolution.
  void _showSessionDissolvedDialog() {
    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFE8F5E9),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تمت الموافقة على الانفصال',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'لقد تم الانفصال بنجاح! تم تقسيم البيانات. سيتم إغلاق التطبيق الآن لتحديث بياناتك الفردية بسلاسة.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF2E7D32),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                exit(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'إغلاق التطبيق وتحديث البيانات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (provider.isStreakInDanger) {
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
      backgroundColor: const Color(0xFFF6EFE6), // very light background
      drawer: _AppDrawer(
        provider: provider,
        pushScreen: _pushScreen,
      ),
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
                  backgroundColor: const Color(0xFFF6EFE6),
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
                      _HouseCard(
                        user: user,
                        provider: provider,
                        pushScreen: _pushScreen,
                        animationTrigger: _gridAnimationTrigger,
                      ),
                      const SizedBox(height: 16),
                      const StreakCard(),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        provider: provider,
                        pushScreen: _pushScreen,
                      ),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'debug_btn',
            backgroundColor: AppColors.charcoal,
            onPressed: () => _showDebugMenu(context),
            child: const Icon(Icons.bug_report, color: AppColors.white),
          ),
          const SizedBox(height: 14),
          _GlowingDepositButton(
            onPressed: () async {
              await DepositDialog.show(context);
              _refreshPendingQuestBadge();
            },
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
class _AppDrawer extends StatefulWidget {
  final SavingsProvider provider;
  final Future<void> Function(Widget) pushScreen;
  const _AppDrawer({required this.provider, required this.pushScreen});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  StreamSubscription<int>? _challengeInvSub;
  int _pendingChallengeCount = 0;

  @override
  void initState() {
    super.initState();
    _challengeInvSub = ChallengeService.incomingInvitationsCountStream().listen(
      (count) {
        if (mounted) setState(() => _pendingChallengeCount = count);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _challengeInvSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return Drawer(
      backgroundColor: const Color(0xFFF6EFE6),
      width: MediaQuery.of(context).size.width * 0.5,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // User Card (Avatar + Full Name)
                    GestureDetector(
                      onTap: () {
                        if (provider.isCooperativeMode) {
                          Navigator.pop(context);
                          widget.pushScreen(const ChallengeDetailsScreen());
                        } else if (provider.isCompetitiveMode) {
                          Navigator.pop(context);
                          widget.pushScreen(const ChallengeCompetitiveScreen());
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: provider.isCooperativeMode 
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.07)
                              : provider.isCompetitiveMode
                                  ? const Color(0xFFFF5722).withValues(alpha: 0.07)
                                  : AppColors.cardFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: provider.isCooperativeMode 
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                : provider.isCompetitiveMode
                                    ? const Color(0xFFFF5722).withValues(alpha: 0.3)
                                    : AppColors.borderLight,
                            width: (provider.isCooperativeMode || provider.isCompetitiveMode) ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (provider.isCompetitiveMode) ...[
                              // My Column
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipOval(
                                      child: FacelessAvatar(
                                        index: provider.avatarIndex,
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (provider.userProfile?.fullName ?? 'أنا').trim().split(' ').first,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.charcoal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Middle "vs" Section
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'تنافسي',
                                      style: TextStyle(
                                        color: Color(0xFFFF5722),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Icon(
                                      Icons.bolt_rounded,
                                      size: 18,
                                      color: Color(0xFFFF5722),
                                    ),
                                  ],
                                ),
                              ),
                              // Partner Column
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipOval(
                                      child: FacelessAvatar(
                                        index: provider.partnerAvatarIndex ?? 0,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (provider.partnerName ?? 'الخصم').trim().split(' ').first,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.charcoal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              if (provider.isCooperativeMode)
                                LinkedAvatars(
                                  userAvatarIndex: provider.avatarIndex,
                                  partnerAvatarIndex: provider.partnerAvatarIndex ?? 0,
                                  size: 36,
                                  overlapMultiplier: 0.5,
                                )
                              else
                                ClipOval(
                                  child: FacelessAvatar(
                                    index: provider.avatarIndex,
                                    size: 38,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      provider.isCooperativeMode
                                          ? '${(provider.userProfile?.fullName ?? 'مستخدم').trim().split(' ').first} & ${(provider.partnerName ?? 'شريكك').trim().split(' ').first}'
                                          : (provider.userProfile?.fullName ?? 'مستخدم').trim().split(' ').first,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: AppColors.charcoal,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (provider.isCooperativeMode) ...[
                                          const Icon(Icons.handshake_rounded, size: 12, color: Color(0xFF2196F3)),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          provider.isCooperativeMode
                                              ? 'تعاوني'
                                              : 'مرحباً بك!',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.borderLight, height: 1),
                    const SizedBox(height: 8),

                    // Menu Items
                    _DrawerItem(
                      icon: Icons.person_outline_rounded,
                      label: 'الملف الشخصي',
                      onTap: () {
                        Navigator.pop(context);
                        widget.pushScreen(const ProfileScreen());
                      },
                    ),

                    _DrawerItem(
                      icon: Icons.emoji_events_rounded,
                      label: 'لوحة الصدارة',
                      onTap: () {
                        Navigator.pop(context);
                        widget.pushScreen(const LeaderboardScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      label: 'الأصدقاء',
                      onTap: () {
                        Navigator.pop(context);
                        widget.pushScreen(const FriendsScreen());
                      },
                    ),
                    // ── نظام التحدي (مع النقطة الحمراء) ──
                    _DrawerItemWithBadge(
                      icon: Icons.shield_rounded,
                      label: 'نظام التحدي',
                      badgeCount: _pendingChallengeCount,
                      onTap: () {
                        Navigator.pop(context);
                        widget.pushScreen(const ChallengeHubScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.storefront_outlined,
                      label: 'المتجر',
                      onTap: () {
                        Navigator.pop(context);
                        AppSnackbar.show(
                          context: context,
                          message: 'ميزة المتجر قادمة قريباً!',
                          isSuccess: false,
                          isInfo: true,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.forest_outlined,
                      label: 'الغابة الحقيقية',
                      onTap: () {
                        Navigator.pop(context);
                        AppSnackbar.show(
                          context: context,
                          message: 'ميزة الغابة الحقيقية قادمة قريباً!',
                          isSuccess: false,
                          isInfo: true,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      label: 'الإعدادات',
                      onTap: () {
                        Navigator.pop(context);
                        widget.pushScreen(const SettingsScreen());
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.borderLight, height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                showAppDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (BuildContext context) {
                    return Dialog(
                      backgroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'تسجيل الخروج',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'هل أنت متأكد أنك تريد تسجيل الخروج؟ سيتم حفظ جميع بياناتك وتقدمك السحابي بأمان.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'إلغاء',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: AppColors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      provider.signOut();
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                                      );
                                    },
                                    child: const Text(
                                      'خروج',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
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
    leading: Icon(icon, color: color, size: 20),
    title: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    horizontalTitleGap: 8,
    minLeadingWidth: 20,
  );
}

/// عنصر Drawer مع نقطة حمراء (Badge) لعرض عدد الإشعارات
class _DrawerItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;
  const _DrawerItemWithBadge({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: AppColors.charcoal, size: 20),
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    title: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    horizontalTitleGap: 8,
    minLeadingWidth: 20,
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
                        'مهمة معلقة',
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
  final Future<void> Function(Widget) pushScreen;
  final int animationTrigger;

  const _HouseCard({
    required this.user,
    required this.provider,
    required this.pushScreen,
    required this.animationTrigger,
  });

  @override
  Widget build(BuildContext context) {
    // Flower images width — used to reserve padding so grid never overlaps them
    const double flowerWidth = 48.0; // slightly reduced to prevent overlap when moving inward
    const double flowerReservedPadding = 30.0; // Adjusted padding to prevent leaf text overlap

    return PhysicalShape(
      clipper: _HouseClipper(),
      elevation: 20, // much stronger 3D elevation
      color: const Color(0xFFEDE4D5), // Darker warm beige
      shadowColor: const Color(0xFF6B4E31).withValues(alpha: 0.45), 
      child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Roof Eaves & Chimney Painter ──
            Positioned.fill(
              child: CustomPaint(
                painter: _RoofPainter(),
              ),
            ),
            // ── White 3D Border ──
            Positioned.fill(
              child: CustomPaint(
                painter: _HouseBorderPainter(),
              ),
            ),
            // ── Main Column: Logo + Grid + Cards ──────────────────────
            Column(
              children: [
                const SizedBox(height: 46), // increased to move logo down

                // ── Brand Logo ──
                Image.asset(
                  'assets/images/Logo.png',
                  height: 76, // restored original logo size
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 0), // reduced to keep grid in the exact same vertical position

                // ── 100-Day Grid (padded so flowers don't overlap) ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: flowerReservedPadding,
                  ),
                  child: SavingsGrid(animationTrigger: animationTrigger),
                ),
                const SizedBox(height: 12),

                // ── "Save for" section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Left: Financial goal
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (provider.isCooperativeMode) {
                              _showCooperativeGoalBottomSheet(
                                  context, user, provider);
                            } else if (provider.isCompetitiveMode) {
                              pushScreen(const ChallengeCompetitiveScreen());
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF3E8), // exact house sticker color
                              border: Border.all(
                                color: const Color(0xFFEDE0CB), // warm border
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F6B4E31), // softer shadow (~12% opacity)
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🎯 ',
                                        style: TextStyle(fontSize: 14)),
                                    Text(
                                      'الهدف المالي',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
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
                                    '${_formatNumber(user.financialGoal)} JD',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'sans-serif'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right: Saved amount
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (provider.isCooperativeMode) {
                              pushScreen(const ChallengeDetailsScreen());
                            } else if (provider.isCompetitiveMode) {
                              pushScreen(const ChallengeCompetitiveScreen());
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF3E8), // exact house sticker color
                              border: Border.all(
                                color: const Color(0xFFEDE0CB), // warm border
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F6B4E31), // softer shadow (~12% opacity)
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المبلغ المدخر',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_formatNumber(provider.totalSaved)} JD',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.green,
                                        fontFamily: 'sans-serif',
                                      ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: user.financialGoal > 0
                                        ? (provider.totalSaved /
                                                user.financialGoal)
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),

            // ── Flower Left — positioned on the left edge, vertically centered on the grid area ──
            Positioned(
              left: 0, // moved inward slightly away from white border
              top: 208, // moved further down
              child: Image.asset(
                'assets/images/Flower_L.png',
                width: flowerWidth,
                height: 205, // slightly smaller to prevent overlap with numbers
                fit: BoxFit.contain,
              ),
            ),

            // ── Flower Right — positioned on the right edge, vertically centered on the grid area ──
            Positioned(
              right: 0, // moved inward slightly away from white border
              top: 208, // moved further down
              child: Image.asset(
                'assets/images/Flower_R.png',
                width: flowerWidth,
                height: 205, // slightly smaller to prevent overlap with numbers
                fit: BoxFit.contain,
              ),
            ),
          ],
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
    final s = value.toStringAsFixed(2);
    if (s.endsWith('0')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// House Clipper — pentagon / envelope shape
// ═══════════════════════════════════════════════════════════════════════════════

class _HouseClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    const double cornerR = 30.0;
    
    // Geometry Constants
    final double peakY = 22.0;
    final double slope = 75.0 / (w / 2); // 75px drop over half width
    final double wallY = peakY + (w / 2) * slope;
    
    // We want the dark roof to protrude by 10 pixels without touching the phone edge.
    // Screen margin is 16.0. 
    // If overhangX = -1.0, painted roof ends at -10.0 (10px protrusion).
    // Silhouette ends at -1.0 - 13.0 = -14.0 (2px gap from phone edge).
    final double overhangX = -1.0; 
    final double overhangY = peakY + (w / 2 - overhangX) * slope;
    
    final Offset p0 = Offset(overhangX, overhangY);
    final Offset p1 = Offset(w / 2, peakY);
    final Offset p2 = Offset(w - overhangX, overhangY);
    
    final double roofThick = 18.0;
    final double bw = 4.0; // White border width
    final double R = (roofThick / 2) + bw; // 9 + 4 = 13.0
    
    // Helper to draw a thick polygon line for the silhouette
    Path createLinePolygon(Offset a, Offset b, double radius) {
      final double dx = b.dx - a.dx;
      final double dy = b.dy - a.dy;
      final double len = math.sqrt(dx * dx + dy * dy);
      final double nx = -dy / len * radius;
      final double ny = dx / len * radius;
      
      final path = Path();
      // CLOCKWISE winding to perfectly union with clockwise circles
      path.moveTo(a.dx - nx, a.dy - ny);
      path.lineTo(b.dx - nx, b.dy - ny);
      path.lineTo(b.dx + nx, b.dy + ny);
      path.lineTo(a.dx + nx, a.dy + ny);
      path.close();
      return path;
    }
    
    // 1. White border silhouette for Roof
    final whiteRoof = Path();
    whiteRoof.addPath(createLinePolygon(p0, p1, R), Offset.zero);
    whiteRoof.addPath(createLinePolygon(p1, p2, R), Offset.zero);
    whiteRoof.addOval(Rect.fromCircle(center: p0, radius: R));
    whiteRoof.addOval(Rect.fromCircle(center: p1, radius: R));
    whiteRoof.addOval(Rect.fromCircle(center: p2, radius: R));

    // 2. White border silhouette for Chimney
    final double pChimLeft = w * 0.68;
    final double pChimW = w * 0.12;
    final double pChimRight = pChimLeft + pChimW;
    final double pCapLeft = pChimLeft - 5;
    final double pCapRight = pChimRight + 5;
    final double pCapTop = 5.0; // Raised chimney
    final double pCapBottom = 19.0;
    final double pTrunkBottom = 90.0; // Extended deep into the roof to close any gaps
    
    final whiteChimney = Path();
    whiteChimney.addRect(Rect.fromLTRB(
      pChimLeft - bw, pCapBottom, pChimRight + bw, pTrunkBottom
    ));
    whiteChimney.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(pCapLeft - bw, pCapTop - bw, pCapRight + bw, pCapBottom + bw),
      Radius.circular(3 + bw),
    ));

    // 3. White House Body Background
    final whiteHouse = Path();
    // Fill the space all the way to the peak to avoid background showing through
    whiteHouse.moveTo(0, wallY);
    whiteHouse.lineTo(w / 2, peakY);
    whiteHouse.lineTo(w, wallY);
    whiteHouse.lineTo(w, h - cornerR);
    whiteHouse.quadraticBezierTo(w, h, w - cornerR, h);
    whiteHouse.lineTo(cornerR, h);
    whiteHouse.quadraticBezierTo(0, h, 0, h - cornerR);
    whiteHouse.close();

    // Combine all to create one massive continuous white sticker silhouette!
    Path silhouette = Path.combine(PathOperation.union, whiteHouse, whiteRoof);
    silhouette = Path.combine(PathOperation.union, silhouette, whiteChimney);
    return silhouette;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HouseBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _HouseClipper().getClip(size);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Half will be clipped by PhysicalShape, leaving a 2.0px inner border
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoofPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    
    // Geometry Constants
    final double peakY = 22.0;
    final double slope = 75.0 / (w / 2); // 75px drop over half width
    
    // Dark layer (Outer layer)
    final double overhangX = -1.0; 
    final double overhangY = peakY + (w / 2 - overhangX) * slope;
    final Offset d0 = Offset(overhangX, overhangY);
    final Offset d1 = Offset(w / 2, peakY);
    final Offset d2 = Offset(w - overhangX, overhangY);
    
    // Light layer (Inner layer, shifted down to expose more thickness)
    final double lX = 4.0; // Ends 4px inside the wall (wider than before, but shorter than dark layer)
    final double lPeakY = peakY + 6.0; // Increased from 3.0 to 6.0 to make it thicker
    final double lY = lPeakY + (w / 2 - lX) * slope;
    final Offset l0 = Offset(lX, lY);
    final Offset l1 = Offset(w / 2, lPeakY);
    final Offset l2 = Offset(w - lX, lY);
    
    final double roofThick = 18.0;
    
    final double pChimLeft = w * 0.68;
    final double pChimW = w * 0.12;
    final double pChimRight = pChimLeft + pChimW;
    final double pCapLeft = pChimLeft - 5;
    final double pCapRight = pChimRight + 5;
    final double pCapTop = 5.0; 
    final double pCapBottom = 19.0;
    
    // Matched Colors
    final chimneyPaint = Paint()..color = const Color(0xFFC0A288); 
    final capPaint = Paint()..color = const Color(0xFFAB8B73);     
    
    // 1. Draw Chimney First (so it tucks naturally behind/under the roof)
    final double roofYAtLeft = peakY + (pChimLeft - w / 2) * slope;
    final double roofYAtRight = peakY + (pChimRight - w / 2) * slope;

    final chimneyPath = Path();
    chimneyPath.moveTo(pChimLeft, pCapBottom);
    chimneyPath.lineTo(pChimRight, pCapBottom);
    chimneyPath.lineTo(pChimRight, roofYAtRight);
    chimneyPath.lineTo(pChimLeft, roofYAtLeft);
    chimneyPath.close();
    
    canvas.drawPath(chimneyPath, chimneyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pCapLeft, pCapTop, pCapRight, pCapBottom),
        const Radius.circular(3),
      ),
      capPaint,
    );

    // 2. Draw Roof Layers
    final lightPath = Path();
    lightPath.moveTo(l0.dx, l0.dy);
    lightPath.lineTo(l1.dx, l1.dy);
    lightPath.lineTo(l2.dx, l2.dy);
    
    final darkPath = Path();
    darkPath.moveTo(d0.dx, d0.dy);
    darkPath.lineTo(d1.dx, d1.dy);
    darkPath.lineTo(d2.dx, d2.dy);
    
    // Bottom Light Layer (Bevel effect)
    final lightRoofPaint = Paint()
      ..color = const Color(0xFFDCC8B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = roofThick
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    // Top Dark Layer
    final darkRoofPaint = Paint()
      ..color = const Color(0xFFC4AB97)
      ..style = PaintingStyle.stroke
      ..strokeWidth = roofThick
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    // Draw light layer first. Because its lines are shorter (lX = 14.0), 
    // it will be completely hidden under the dark layer at the edges!
    canvas.drawPath(lightPath, lightRoofPaint);
    
    // Draw dark layer. It has longer lines (dX = 2.0), so it forms the protruding eave tips!
    canvas.drawPath(darkPath, darkRoofPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  final Future<void> Function(Widget) pushScreen;
  const _SummaryRow({required this.provider, required this.pushScreen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
          label: 'الأيام',
          value: '${provider.completedDays}/100',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(width: 8),
        _StatBox(
          label: 'العمليات',
          value: '${provider.deposits.length}',
          icon: Icons.receipt_long_outlined,
          onTap: provider.isCooperativeMode
              ? () => pushScreen(const ChallengeDetailsScreen())
              : null,
        ),
        const SizedBox(width: 8),
        _StatBox(
          label: 'السجل',
          value: 'عرض',
          icon: Icons.history,
          onTap: () => pushScreen(const ActivityLogScreen()),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2), // exact house sticker color
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2), // white 3D border
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A6B4E31), // subtle shadow for card pop
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20, // slightly smaller

                fontWeight: FontWeight.w800,
                color: Color(0xFF3A9855), // matching the vibrant green
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A7A7A), // neutral gray
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Cooperative Goal Bottom Sheet ──────────────────────────────────────────
void _showCooperativeGoalBottomSheet(BuildContext context, dynamic user, SavingsProvider provider) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  final partnerUid = provider.partnerUid;
  final partnerName = provider.partnerName ?? 'شريكك';
  final myName = user.fullName ?? 'أنا';
  final partnerAvatar = provider.partnerAvatarIndex ?? 0;
  final myAvatar = provider.avatarIndex;

  final deposits = provider.deposits;
  double myContribution = 0.0;
  double partnerContribution = 0.0;
  for (final dep in deposits) {
    if (dep.depositedBy == myUid) {
      myContribution += dep.amount;
    } else if (dep.depositedBy == partnerUid) {
      partnerContribution += dep.amount;
    }
  }

  final financialGoal = user.financialGoal;
  final targetPerPerson = financialGoal / 2;

  final myProgress = targetPerPerson > 0 ? (myContribution / targetPerPerson).clamp(0.0, 1.0) : 0.0;
  final partnerProgress = targetPerPerson > 0 ? (partnerContribution / targetPerPerson).clamp(0.0, 1.0) : 0.0;

  final myRemaining = (targetPerPerson - myContribution).clamp(0.0, double.infinity);
  final partnerRemaining = (targetPerPerson - partnerContribution).clamp(0.0, double.infinity);

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFFF6EFE6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle indicator ──
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
              const SizedBox(height: 18),

              // ── Header ──
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    'تقسيم الهدف المالي المشترك',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.charcoal,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الهدف المالي مقسم بالتساوي (50% لكل شريك) لتشجيع التعاون المالي والمساهمة المتكافئة.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),

              // ── Total Summary Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الهدف الإجمالي للمجموعة',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${financialGoal.toStringAsFixed(2)} JD',
                          style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'sans-serif'),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'المطلوب من كل فرد',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${targetPerPerson.toStringAsFixed(2)} JD',
                          style: const TextStyle(color: AppColors.charcoal, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'sans-serif'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── My Section ──
              _buildPartnerGoalProgress(
                context: context,
                name: 'أنت ($myName)',
                avatarIndex: myAvatar,
                saved: myContribution,
                target: targetPerPerson,
                remaining: myRemaining,
                progress: myProgress,
                isMe: true,
              ),
              const SizedBox(height: 20),

              // ── Partner Section ──
              _buildPartnerGoalProgress(
                context: context,
                name: partnerName,
                avatarIndex: partnerAvatar,
                saved: partnerContribution,
                target: targetPerPerson,
                remaining: partnerRemaining,
                progress: partnerProgress,
                isMe: false,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildPartnerGoalProgress({
  required BuildContext context,
  required String name,
  required int avatarIndex,
  required double saved,
  required double target,
  required double remaining,
  required double progress,
  required bool isMe,
}) {
  final accentColor = isMe ? const Color(0xFF4CAF50) : const Color(0xFF388E3C);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          ClipOval(child: FacelessAvatar(index: avatarIndex, size: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'المتبقي: ${remaining.toStringAsFixed(2)} JD',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'sans-serif'),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${saved.toStringAsFixed(2)} / ${target.toStringAsFixed(2)} JD',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'sans-serif'),
              ),
              const SizedBox(height: 2),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: AppColors.borderLight,
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Modern Glowing Add Deposit Button (كبسة إضافة إيداع العصرية والمضيئة)
// ═══════════════════════════════════════════════════════════════════════════════

class _GlowingDepositButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _GlowingDepositButton({required this.onPressed});

  @override
  State<_GlowingDepositButton> createState() => _GlowingDepositButtonState();
}

class _GlowingDepositButtonState extends State<_GlowingDepositButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _spreadAnimation;
  late Animation<double> _alphaAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 10.0, end: 22.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _spreadAnimation = Tween<double>(begin: 1.5, end: 5.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _alphaAnimation = Tween<double>(begin: 0.35, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final currentScale = _isPressed ? 0.90 : _scaleAnimation.value;
        return Transform.scale(
          scale: currentScale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: _alphaAnimation.value),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _spreadAnimation.value,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 2.0,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
