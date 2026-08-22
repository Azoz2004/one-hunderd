import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:one_hunderd/features/challenges/models/challenge_invitation.dart';
import 'package:one_hunderd/features/challenges/services/challenge_service.dart';
import 'package:one_hunderd/features/friends/services/friends_service.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_explanation_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_details_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_competitive_stats_screen.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart'; // for FacelessAvatar, LinkedAvatars
import 'package:one_hunderd/features/home/screens/home_screen.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';

/// شاشة نظام التحدي الرئيسية
///
/// تحتوي على:
/// 1. زر طلبات الدعوة الواردة (أعلى)
/// 2. بطاقتين: التعاوني (مفعّل) والتنافسي (قريباً)
/// 3. زر "تعرف على الأنظمة" (أسفل)
class ChallengeHubScreen extends StatefulWidget {
  const ChallengeHubScreen({super.key});

  @override
  State<ChallengeHubScreen> createState() => _ChallengeHubScreenState();
}

class _ChallengeHubScreenState extends State<ChallengeHubScreen> {
  ChallengeInvitation? _activeChallenge;
  bool _loadingActive = true;

  @override
  void initState() {
    super.initState();
    _loadActiveChallenge();
  }

  Future<void> _loadActiveChallenge() async {
    try {
      final provider = context.read<SavingsProvider>();
      if (provider.activeSessionId == null) {
        if (mounted) {
          setState(() {
            _activeChallenge = null;
            _loadingActive = false;
          });
        }
        return;
      }
      final active = await ChallengeService.getMyActiveChallenge();
      if (mounted) {
        setState(() {
          _activeChallenge = active;
          _loadingActive = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  void _showDisconnectWarningDialog(BuildContext context) {
    final provider = Provider.of<SavingsProvider>(context, listen: false);
    final isCompetitive = provider.isCompetitiveMode;
    final typeName = isCompetitive ? 'التنافسي' : 'التعاوني المشترك';

    showAppDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.cardFill,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'طلب الانفصال عن التحدي',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.charcoal),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في طلب الانفصال عن التحدي $typeName؟',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.charcoal),
              ),
              const SizedBox(height: 10),
              // Mutual consent notice
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE65100)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'يجب أن يوافق شريكك أيضاً على الانفصال لتتم العملية بنجاح. سيُرسَل إليه إشعار بطلبك.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'عواقب الانفصال:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
              ),
              SizedBox(height: 6),
              Text(
                isCompetitive
                    ? '• لن تشاهد تقدم خصمك بعد الآن.\n'
                      '• سيتحول التحدي الخاص بك إلى النظام الفردي.\n'
                      '• ستحتفظ بإيداعاتك وعملاتك الخشبية الحالية.\n'
                      '• سيتم إغلاق التطبيق لتحديث البيانات.'
                    : '• يحتفظ كل شريك بإيداعاته الفردية فقط.\n'
                      '• يُعاد حساب ستريك الالتزام لكل شريك بشكل منفصل.\n'
                      '• تُقسَّم المسكوكات وأطواق النجاة بالتساوي 50/50.\n'
                      '• يتحوّل نوع التحدي لكلا الطرفين إلى تحدٍّ فردي.\n'
                      '• سيتم إغلاق التطبيق لكلا الطرفين لتحديث البيانات.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<SavingsProvider>().requestSeparation();
                  if (context.mounted) {
                    AppSnackbar.show(
                      context: context,
                      message: 'تم إرسال طلب الانفصال. بانتظار موافقة شريكك...',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackbar.show(
                      context: context,
                      message: 'فشل في إرسال الطلب: $e',
                      isSuccess: false,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('إرسال طلب الانفصال', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AppBar(
            title: const Text(
              'نظام التحدي',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            centerTitle: false,
            backgroundColor: AppColors.background,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // ── زر طلبات الدعوة ──
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: StreamBuilder<int>(
                  stream: ChallengeService.incomingInvitationsCountStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    final inChallenge = _activeChallenge != null && !_loadingActive;
                    return GestureDetector(
                      onTap: () {
                        if (inChallenge) {
                          AppSnackbar.show(
                            context: context,
                            message: 'أنت بالفعل في تحدي نشط!',
                            isSuccess: false,
                          );
                        } else {
                          _showInvitationsSheet(context);
                        }
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: inChallenge ? 0.4 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    inChallenge
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.mail_outline_rounded,
                                    size: 20,
                                    color: AppColors.charcoal,
                                  ),
                                  if (!inChallenge && count > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'الطلبات',
                                style: TextStyle(
                                  color: AppColors.charcoal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              // ── حالة التحميل ──
              if (_loadingActive)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(
                    color: AppColors.charcoal,
                    backgroundColor: AppColors.borderLight,
                  ),
                ),

              // ── بطاقة التحدي النشط + زر الانفصال ──
              if (!_loadingActive && _activeChallenge != null)
                Consumer<SavingsProvider>(
                  builder: (context, provider, _) {
                    final isPendingByMe = provider.hasCurrentRequestedSeparation;
                    return Column(
                      children: [
                        _ActiveChallengeCard(invitation: _activeChallenge!),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isPendingByMe
                                ? null
                                : () => _showDisconnectWarningDialog(context),
                            icon: Icon(
                              isPendingByMe
                                  ? Icons.hourglass_top_rounded
                                  : Icons.link_off_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isPendingByMe
                                  ? 'بانتظار موافقة الشريك... ⏳'
                                  : 'انفصال عن التحدي',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isPendingByMe
                                  ? const Color(0xFFE65100)
                                  : AppColors.error,
                              disabledForegroundColor:
                                  const Color(0xFFE65100).withValues(alpha: 0.6),
                              side: BorderSide(
                                color: isPendingByMe
                                    ? const Color(0xFFE65100).withValues(alpha: 0.5)
                                    : AppColors.error.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

              // ── بطاقات الأنظمة (تظهر فقط إذا لم يكن في تحدي) ──
              if (!_loadingActive && _activeChallenge == null)
                Expanded(
                  child: Column(
                    children: [
                      // ── التعاوني ──
                      Expanded(
                        child: _ChallengeTypeCard(
                          icon: Icons.handshake_rounded,
                          iconColor: const Color(0xFF4CAF50),
                          title: 'التحدي التعاوني',
                          description: 'ادعِ صديقك ليساعدك على إكمال\nتحدي الـ 100 يوم سوا!',
                          isEnabled: true,
                          onTap: () => _showFriendsPicker(context, isCompetitive: false),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── التنافسي ──
                      Expanded(
                        child: _ChallengeTypeCard(
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFFF5722),
                          title: 'التحدي التنافسي',
                          description: 'نافس أصدقاءك وشوف مين بيوفر أكثر!',
                          isEnabled: true,
                          comingSoon: false,
                          onTap: () => _showFriendsPicker(context, isCompetitive: true),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

              // ── زر تعرف على الأنظمة ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppScalePageRoute(
                        page: const ChallengeExplanationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('تعرف على الأنظمة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.charcoal,
                    side: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // Bottom Sheets
  // ═══════════════════════════════════════════════════════════════════════════

  /// عرض قائمة الدعوات الواردة
  void _showInvitationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.cardFill,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (sheetCtx, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.mail_rounded,
                        size: 20, color: AppColors.charcoal),
                    SizedBox(width: 8),
                    Text(
                      'طلبات الدعوة',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderLight, height: 1),
              Expanded(
                child: StreamBuilder<List<ChallengeInvitation>>(
                  stream: ChallengeService.incomingInvitationsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.charcoal,
                        ),
                      );
                    }

                    final invitations = snapshot.data ?? [];
                    if (invitations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 48,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد دعوات حالياً',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: invitations.length,
                      itemBuilder: (_, i) => _InvitationCard(
                        invitation: invitations[i],
                        onAccept: () async {
                          try {
                            // 1. احفظ الـ provider لتتمكن من استدعائه حتى لو اختفت الـ widget
                            final provider = context.read<SavingsProvider>();
                            
                            // 2. إغلاق الـ Bottom Sheet فوراً لمنع تعارض الـ streams
                            Navigator.pop(context);

                            // 3. قبول الدعوة في السيرفر
                            await ChallengeService.acceptInvitation(
                              invitations[i].id,
                            );
                            
                            // 4. تهيئة الحساب بالبيانات الجديدة
                            await provider.init();
                            
                            // 5. إظهار رسالة النجاح المنبثقة
                            if (context.mounted) {
                              final isCompetitive = invitations[i].type == ChallengeType.competitive;
                              final title = isCompetitive ? 'بدأ التحدي التنافسي!' : 'بدأ التحدي التعاوني!';
                              final message = isCompetitive 
                                  ? 'تم قبول دعوة التحدي التنافسي بنجاح! سيتم إعادة توجيهك الآن لتهيئة مساحة التحدي.'
                                  : 'تم قبول دعوة التحدي التعاوني بنجاح! سيتم إعادة توجيهك الآن لتهيئة البيانات المشتركة مع شريكك.';

                              showAppDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctxDialog) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    title: Row(
                                      children: [
                                        Icon(
                                          isCompetitive ? Icons.local_fire_department_rounded : Icons.handshake_rounded, 
                                          color: const Color(0xFF2E7D32), 
                                          size: 28
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 17,
                                              color: Color(0xFF1B5E20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      message,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2E7D32),
                                        height: 1.5,
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                                            (route) => false,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E7D32),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text(
                                          'بدء التحدي',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppSnackbar.show(
                                context: context,
                                message: '$e',
                                isSuccess: false,
                              );
                            }
                            rethrow;
                          }
                        },
                        onReject: () async {
                          try {
                            await ChallengeService.rejectInvitation(
                              invitations[i].id,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              AppSnackbar.show(
                                context: context,
                                message: '$e',
                                isSuccess: false,
                              );
                            }
                            rethrow;
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عرض قائمة الأصدقاء لاختيار شخص لدعوته
  void _showFriendsPicker(BuildContext context, {required bool isCompetitive}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.cardFill,
      builder: (ctx) => _FriendsPickerSheet(
        isCompetitive: isCompetitive,
        onInviteSent: () {
          if (mounted) _loadActiveChallenge();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// بطاقة نوع التحدي
// ═══════════════════════════════════════════════════════════════════════════════

class _ChallengeTypeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isEnabled;
  final bool comingSoon;
  final VoidCallback onTap;

  const _ChallengeTypeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isEnabled,
    this.comingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.cardFill : AppColors.cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isEnabled ? iconColor.withValues(alpha: 0.4) : AppColors.borderLight,
            width: isEnabled ? 1.5 : 1,
          ),
        ),
        child: Opacity(
          opacity: comingSoon ? 0.5 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (comingSoon) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'قريباً',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (isEnabled) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded,
                          size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        'ادعُ صديق',
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// بطاقة التحدي النشط
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveChallengeCard extends StatelessWidget {
  final ChallengeInvitation invitation;

  const _ActiveChallengeCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isInviter = invitation.fromUid == myUid;
    final partnerUid = isInviter ? invitation.toUid : invitation.fromUid;

    final partnerName = provider.partnerName ?? 'صديق';
    final partnerAvatar = provider.partnerAvatarIndex ?? 0;
    final myAvatar = provider.avatarIndex;

    final isCompetitive = invitation.type == ChallengeType.competitive;

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

    final totalDays = provider.completedDays;
    final currentStreak = provider.currentStreak;
    final woodenCoins = provider.woodenCoins;
    final lifebuoys = provider.lifebuoys;
    final financialGoal = provider.userProfile?.financialGoal ?? 5050.0;

    final totalSaved = myContribution + partnerContribution;
    final goalProgress = (financialGoal > 0 ? (totalSaved / financialGoal).clamp(0.0, 1.0) : 0.0);
    final dayProgress = totalDays / 100.0;

    final themeColor = isCompetitive ? const Color(0xFFFF5722) : const Color(0xFF4CAF50);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppScalePageRoute(
            page: isCompetitive
                ? const ChallengeCompetitiveStatsScreen()
                : const ChallengeDetailsScreen(),
          ),
        );
      },
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── رأس البطاقة: أيقونة + معلومات الشريك ──
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompetitive ? Icons.bolt_rounded : Icons.handshake_rounded,
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isCompetitive ? 'تحدي تنافسي نشط ⚡' : 'تحدي تعاوني نشط 🤝',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCompetitive ? 'منافسك: $partnerName' : 'شريكك: $partnerName',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LinkedAvatars(
                          userAvatarIndex: myAvatar,
                          partnerAvatarIndex: partnerAvatar,
                          size: 30,
                          overlapMultiplier: 0.4,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 12),

          if (isCompetitive) ...[
            // ── تقدم كل لاعب بشكل مستقل في التحدي التنافسي ──
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(partnerUid).get(),
              builder: (context, snapshot) {
                int partnerDays = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  partnerDays = (data['completed_days_count'] as num?)?.toInt() ?? 0;
                }
                final partnerDayProgress = partnerDays / 100.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // تقدم اللاعب الحالي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        const Text(
                          'تقدمك أنت:',
                          style: TextStyle(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$totalDays / 100 يوم (${(dayProgress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dayProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // تقدم الخصم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          'تقدم $partnerName:',
                          style: const TextStyle(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$partnerDays / 100 يوم (${(partnerDayProgress * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            color: Color(0xFF667EEA),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: partnerDayProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            // ── التقدم المشترك في التحدي التعاوني ──
            // شريط تقدم الأيام
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  'الأيام المشتركة: $totalDays / 100',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${(dayProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: dayProgress,
                minHeight: 8,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
            ),
            const SizedBox(height: 12),

            // شريط تقدم الهدف المالي
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  'الهدف المشترك: ${financialGoal.toStringAsFixed(2)} JD',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFamily: 'sans-serif',
                  ),
                ),
                Text(
                  'المجموع: ${totalSaved.toStringAsFixed(2)} JD',
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goalProgress,
                minHeight: 8,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
            ),
            const SizedBox(height: 12),

            // مساهمة الطرفين
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    children: [
                      const Text(
                        'مساهمتك',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${myContribution.toStringAsFixed(2)} JD',
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: AppColors.borderLight),
                  Column(
                    children: [
                      Text(
                        'مساهمة $partnerName',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${partnerContribution.toStringAsFixed(2)} JD',
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // شارات: الإطار، المسكوكات، الطوق النجاة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            textDirection: TextDirection.rtl,
            children: [
              _StatBadge(
                icon: '🔥',
                label: isCompetitive ? 'سلسلتك' : 'السلسلة',
                value: '$currentStreak يوم',
              ),
              _StatBadge(
                icon: '🪙',
                label: isCompetitive ? 'مسكوكاتك' : 'المسكوكات',
                value: '$woodenCoins',
              ),
              _StatBadge(
                icon: '🛟',
                label: isCompetitive ? 'أطواقك' : 'أطواق النجاة',
                value: '$lifebuoys',
              ),
            ],
          ),
        ],
      ),
    ), // end Container
    ); // end GestureDetector
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// شارة إحصاء بسيطة (مستخدمة داخل بطاقة التحدي النشط)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatBadge extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatBadge({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// بطاقة دعوة واردة
// ═══════════════════════════════════════════════════════════════════════════════

class _InvitationCard extends StatefulWidget {
  final ChallengeInvitation invitation;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
    final typeLabel =
        inv.type == ChallengeType.cooperative ? 'تعاوني' : 'تنافسي';
    final typeIcon = inv.type == ChallengeType.cooperative
        ? Icons.handshake_rounded
        : Icons.bolt_rounded;
    final typeColor = inv.type == ChallengeType.cooperative
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF5722);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // ── معلومات المرسل ──
          Row(
            children: [
              ClipOval(
                child: FacelessAvatar(
                  index: inv.senderAvatarIndex,
                  size: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      inv.senderName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'دعوة تحدي $typeLabel',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(typeIcon, size: 14, color: typeColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── أزرار القبول والرفض ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing
                      ? null
                      : () async {
                          setState(() => _processing = true);
                          try {
                            await widget.onReject();
                          } catch (_) {
                            if (mounted) setState(() => _processing = false);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'رفض',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processing
                      ? null
                      : () async {
                          setState(() => _processing = true);
                          try {
                            await widget.onAccept();
                          } catch (_) {
                            if (mounted) setState(() => _processing = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'قبول',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// قائمة اختيار الأصدقاء لإرسال الدعوة
// ═══════════════════════════════════════════════════════════════════════════════

class _FriendsPickerSheet extends StatefulWidget {
  final VoidCallback onInviteSent;
  final bool isCompetitive;

  const _FriendsPickerSheet({required this.onInviteSent, this.isCompetitive = false});

  @override
  State<_FriendsPickerSheet> createState() => _FriendsPickerSheetState();
}

class _FriendsPickerSheetState extends State<_FriendsPickerSheet> {
  List<FriendUser>? _friends;
  bool _loading = true;
  final Set<String> _sentInvitations = {};
  String? _sendingToUid;
  String? _cancellingUid;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await FriendsService.getFriends();

      // جلب الدعوات المرسلة المعلقة لتظليل الأصدقاء المدعوين
      final sentInvitations =
          await ChallengeService.getSentPendingInvitations();
      final sentUids = sentInvitations.map((inv) => inv.toUid).toSet();

      if (mounted) {
        setState(() {
          _friends = friends;
          _sentInvitations.addAll(sentUids);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // مساعد: تنظيف رسالة الخطأ من كلمة Exception:
  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) return msg.substring('Exception: '.length);
    return msg;
  }

  Future<void> _cancelInvitation(String friendUid) async {
    setState(() => _cancellingUid = friendUid);
    try {
      await ChallengeService.cancelInvitationByUid(friendUid);
      if (mounted) {
        setState(() {
          _sentInvitations.remove(friendUid);
          _cancellingUid = null;
        });
        widget.onInviteSent(); // Refresh count if needed
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancellingUid = null);
        AppSnackbar.show(
          context: context,
          message: _cleanError(e),
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _sendInvitation(FriendUser friend) async {
    setState(() => _sendingToUid = friend.uid);
    try {
      await ChallengeService.sendInvitation(
        toUid: friend.uid,
        type: widget.isCompetitive ? ChallengeType.competitive : ChallengeType.cooperative,
      );
      if (mounted) {
        setState(() {
          _sentInvitations.add(friend.uid);
          _sendingToUid = null;
        });
        widget.onInviteSent();
        AppSnackbar.show(
          context: context,
          message: 'تم إرسال الدعوة إلى ${friend.fullName}!',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingToUid = null);
        AppSnackbar.show(
          context: context,
          message: '$e',
          isSuccess: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (sheetCtx, scrollController) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_add_rounded,
                      size: 20, color: AppColors.charcoal),
                  SizedBox(width: 8),
                  Text(
                    'اختر صديق للدعوة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'اختر صديقاً لدعوته إلى التحدي التعاوني',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderLight, height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.charcoal,
                      ),
                    )
                  : (_friends == null || _friends!.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'لا يوجد أصدقاء حالياً\nأضف أصدقاء أولاً!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _friends!.length,
                          itemBuilder: (_, i) {
                            final friend = _friends![i];
                            final alreadySent =
                                _sentInvitations.contains(friend.uid);
                            final isSending = _sendingToUid == friend.uid;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: alreadySent
                                    ? AppColors.green.withValues(alpha: 0.06)
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: alreadySent
                                      ? AppColors.green
                                          .withValues(alpha: 0.3)
                                      : AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: FacelessAvatar(
                                      index: friend.avatarIndex,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      friend.fullName,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: AppColors.charcoal,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (alreadySent)
                                    GestureDetector(
                                      onTap: _cancellingUid == friend.uid
                                          ? null
                                          : () => _cancelInvitation(friend.uid),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: _cancellingUid == friend.uid
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.error,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close_rounded,
                                                      size: 14,
                                                      color: AppColors.error),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'إلغاء الدعوة',
                                                    style: TextStyle(
                                                      color: AppColors.error,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: isSending
                                          ? null
                                          : () => _sendInvitation(friend),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.charcoal,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: isSending
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: AppColors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'دعوة',
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
