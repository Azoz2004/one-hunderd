import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart';

/// شاشة إحصائيات المواجهة المباشرة
/// تجلب بيانات الخصم من Firestore وتعرض مقارنة مفصّلة بين اللاعبين
class ChallengeCompetitiveStatsScreen extends StatefulWidget {
  const ChallengeCompetitiveStatsScreen({super.key});

  @override
  State<ChallengeCompetitiveStatsScreen> createState() =>
      _ChallengeCompetitiveStatsScreenState();
}

class _ChallengeCompetitiveStatsScreenState
    extends State<ChallengeCompetitiveStatsScreen> {
  bool _loading = true;

  // ── بيانات الخصم المجلوبة من Firestore ────────────────────────────
  int _partnerDays = 0;
  int _partnerStreak = 0;
  bool _partnerHasTodayDeposit = false;
  String? _partnerLastDepositDate;
  int _partnerWoodenCoins = 0;
  int _partnerLifebuoysUsed = 0;

  StreamSubscription<DocumentSnapshot>? _partnerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToPartnerData());
  }

  @override
  void dispose() {
    _partnerSubscription?.cancel();
    super.dispose();
  }

  /// يستمع إلى بيانات الخصم الحية من Firestore
  void _listenToPartnerData() {
    if (!mounted) return;
    setState(() => _loading = true);

    final provider = context.read<SavingsProvider>();
    final partnerUid = provider.competitivePartnerUid;

    if (partnerUid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _partnerSubscription?.cancel();
    _partnerSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(partnerUid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final data = doc.data() ?? {};

      // ── SKILL 4: استخدام as num? لأمان الأنواع ──
      final partnerDays = (data['completed_days_count'] as num?)?.toInt() ?? 0;
      final partnerStreak = (data['current_streak_v1'] as num?)?.toInt() ?? 0;
      final lastDepositStr = data['last_deposit_date_v1'] as String?;

      // التحقق من إيداع اليوم بمقارنة التاريخ
      bool partnerHasToday = false;
      if (lastDepositStr != null) {
        try {
          final lastDeposit = DateTime.parse(lastDepositStr);
          final today = DateTime.now();
          partnerHasToday = lastDeposit.year == today.year &&
              lastDeposit.month == today.month &&
              lastDeposit.day == today.day;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _partnerDays = partnerDays;
          _partnerStreak = partnerStreak;
          _partnerHasTodayDeposit = partnerHasToday;
          _partnerLastDepositDate = lastDepositStr;
          _partnerWoodenCoins = (data['wooden_coins_v1'] as num?)?.toInt() ?? 0;
          _partnerLifebuoysUsed = (data['lifebuoys_used_v1'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _refreshData() async {
    _listenToPartnerData();
  }

  /// يُحوّل تاريخ ISO إلى صيغة d/m/yyyy
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'لا يوجد';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'إحصائيات المواجهة 📊',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: false,
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: true,
          leading: BackButton(color: AppColors.charcoal),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5722),
                ),
              )
            : Consumer<SavingsProvider>(
                builder: (context, provider, _) {
                  final myName = provider.userProfile?.fullName ?? 'أنا';
                  final partnerName =
                      provider.competitivePartnerName ?? 'الخصم';
                  final myDays = provider.completedDays;
                  final myStreak = provider.currentStreak;
                  final myAvatar = provider.avatarIndex;
                  final partnerAvatar =
                      provider.competitivePartnerAvatarIndex ?? 0;
                  final myHasToday = provider.hasTodayDeposit;
                  final myLastDeposit =
                      provider.lastDepositDate?.toIso8601String();

                  final dayDiff = myDays - _partnerDays;
                  final isLeading = dayDiff > 0;
                  final isTied = dayDiff == 0;

                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    color: const Color(0xFFFF5722),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── حالة اليوم ─────────────────────────────────
                          const _SectionTitle(title: 'حالة الإنجاز لليوم'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _TodayStatusCard(
                                  name: myName,
                                  avatarIndex: myAvatar,
                                  hasDeposit: myHasToday,
                                  isMe: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TodayStatusCard(
                                  name: partnerName,
                                  avatarIndex: partnerAvatar,
                                  hasDeposit: _partnerHasTodayDeposit,
                                  isMe: false,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── ملخص السباق التنافسي ────────────────────────
                          _MatchStatusHeader(
                            myDays: myDays,
                            partnerDays: _partnerDays,
                            isLeading: isLeading,
                            isTied: isTied,
                            partnerName: partnerName,
                          ),

                          const SizedBox(height: 24),

                          // ── مقارنة الإحصائيات ─────────────────────────────
                          const _SectionTitle(title: 'مقارنة الإحصائيات'),
                          const SizedBox(height: 12),
                          
                          // 1. الأيام المنجزة
                          _StatComparisonCard(
                            title: 'الأيام المنجزة',
                            icon: '📅',
                            myValue: '$myDays / 100',
                            partnerValue: '$_partnerDays / 100',
                            myProgress: myDays / 100.0,
                            partnerProgress: _partnerDays / 100.0,
                            themeColor: const Color(0xFFFF5722),
                            myWins: myDays > _partnerDays
                                ? true
                                : myDays < _partnerDays
                                    ? false
                                    : null,
                          ),

                          // 2. السلسلة الحالية
                          _StatComparisonCard(
                            title: 'السلسلة الحالية',
                            icon: '🔥',
                            myValue: '$myStreak يوم',
                            partnerValue: '$_partnerStreak يوم',
                            myProgress: myStreak > 0 ? (myStreak / (myStreak > _partnerStreak ? myStreak : _partnerStreak).toDouble()).clamp(0.0, 1.0) : 0.0,
                            partnerProgress: _partnerStreak > 0 ? (_partnerStreak / (myStreak > _partnerStreak ? myStreak : _partnerStreak).toDouble()).clamp(0.0, 1.0) : 0.0,
                            themeColor: const Color(0xFFFF9800),
                            myWins: myStreak > _partnerStreak
                                ? true
                                : myStreak < _partnerStreak
                                    ? false
                                    : null,
                          ),

                          // 3. عدد استخدام أطواق النجاة
                          _StatComparisonCard(
                            title: 'عدد استخدام أطواق النجاة',
                            icon: '🛡️',
                            myValue: '${provider.lifebuoysUsed} مرات',
                            partnerValue: '$_partnerLifebuoysUsed مرات',
                            myProgress: provider.lifebuoysUsed > 0 ? (provider.lifebuoysUsed / (provider.lifebuoysUsed > _partnerLifebuoysUsed ? provider.lifebuoysUsed : _partnerLifebuoysUsed).toDouble()).clamp(0.0, 1.0) : 0.0,
                            partnerProgress: _partnerLifebuoysUsed > 0 ? (_partnerLifebuoysUsed / (provider.lifebuoysUsed > _partnerLifebuoysUsed ? provider.lifebuoysUsed : _partnerLifebuoysUsed).toDouble()).clamp(0.0, 1.0) : 0.0,
                            themeColor: const Color(0xFF2196F3),
                            myWins: provider.lifebuoysUsed > _partnerLifebuoysUsed
                                ? true
                                : provider.lifebuoysUsed < _partnerLifebuoysUsed
                                    ? false
                                    : null,
                          ),

                          // 4. المسكوكات المتوفرة
                          _StatComparisonCard(
                            title: 'المسكوكات المتوفرة',
                            icon: '🪙',
                            myValue: '${provider.woodenCoins}',
                            partnerValue: '$_partnerWoodenCoins',
                            myProgress: provider.woodenCoins > 0 ? (provider.woodenCoins / (provider.woodenCoins > _partnerWoodenCoins ? provider.woodenCoins : _partnerWoodenCoins).toDouble()).clamp(0.0, 1.0) : 0.0,
                            partnerProgress: _partnerWoodenCoins > 0 ? (_partnerWoodenCoins / (provider.woodenCoins > _partnerWoodenCoins ? provider.woodenCoins : _partnerWoodenCoins).toDouble()).clamp(0.0, 1.0) : 0.0,
                            themeColor: const Color(0xFFFFC107),
                            myWins: provider.woodenCoins > _partnerWoodenCoins
                                ? true
                                : provider.woodenCoins < _partnerWoodenCoins
                                    ? false
                                    : null,
                          ),

                          // 5. آخر نشاط إيداع
                          _StatComparisonCard(
                            title: 'آخر نشاط إيداع',
                            icon: '🕒',
                            myValue: _formatDate(myLastDeposit),
                            partnerValue: _formatDate(_partnerLastDepositDate),
                            themeColor: Colors.grey,
                            myWins: null,
                          ),

                          const SizedBox(height: 20),

                          // ── تلميح التحديث ──────────────────────────────
                          Text(
                            'اسحب لأسفل للتحديث',
                            style: TextStyle(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets مساعدة
// ══════════════════════════════════════════════════════════════════════════════

/// عنوان القسم
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: AppColors.charcoal,
        ),
      ),
    );
  }
}

/// بطاقة حالة إيداع اليوم لكل لاعب
class _TodayStatusCard extends StatelessWidget {
  final String name;
  final int avatarIndex;
  final bool hasDeposit;
  final bool isMe;

  const _TodayStatusCard({
    required this.name,
    required this.avatarIndex,
    required this.hasDeposit,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hasDeposit
            ? LinearGradient(
                colors: [
                  green.withValues(alpha: 0.1),
                  green.withValues(alpha: 0.03),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
        color: hasDeposit ? null : AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDeposit
              ? green.withValues(alpha: 0.5)
              : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: hasDeposit
            ? [
                BoxShadow(
                  color: green.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasDeposit ? green : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: FacelessAvatar(index: avatarIndex, size: 54),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.charcoal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hasDeposit ? green : AppColors.borderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasDeposit ? 'أنجز اليوم ✅' : 'لم ينجز بعد',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: hasDeposit
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchStatusHeader extends StatelessWidget {
  final int myDays;
  final int partnerDays;
  final bool isLeading;
  final bool isTied;
  final String partnerName;

  const _MatchStatusHeader({
    required this.myDays,
    required this.partnerDays,
    required this.isLeading,
    required this.isTied,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF5722);
    const green = Color(0xFF4CAF50);

    final statusColor = isTied ? AppColors.charcoal : (isLeading ? green : orange);
    final statusText = isTied
        ? 'تعادل! أنتما على نفس خط التقدم 🤝'
        : isLeading
            ? 'أنت متقدم بفارق ${myDays - partnerDays} يوم! حافظ على تقدمك 🏆'
            : '$partnerName متقدم بفارق ${partnerDays - myDays} يوم! ضاعف جهودك ⚡';

    final icon = isTied ? '🤝' : (isLeading ? '🏆' : '⚡');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة المواجهة الحالية',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    height: 1.3,
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

class _StatComparisonCard extends StatelessWidget {
  final String title;
  final String icon;
  final String myValue;
  final String partnerValue;
  final double? myProgress;
  final double? partnerProgress;
  final Color themeColor;
  final bool? myWins;

  const _StatComparisonCard({
    required this.title,
    required this.icon,
    required this.myValue,
    required this.partnerValue,
    this.myProgress,
    this.partnerProgress,
    required this.themeColor,
    this.myWins,
  });

  @override
  Widget build(BuildContext context) {
    const winningColor = Color(0xFF4CAF50);
    const losingColor = Color(0xFFFF5722);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.charcoal,
                ),
              ),
              const Spacer(),
              if (myWins == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: winningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'أنت متفوق 🏆',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: winningColor,
                    ),
                  ),
                )
              else if (myWins == false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: losingColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'الخصم متفوق ⚡',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: losingColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أنت',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      myValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: myWins == true ? winningColor : (myWins == false ? AppColors.charcoal : AppColors.charcoal),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: AppColors.borderLight,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الخصم',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partnerValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: myWins == false ? winningColor : (myWins == true ? AppColors.charcoal : AppColors.charcoal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (myProgress != null && partnerProgress != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: myProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        myWins == true ? winningColor : themeColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: partnerProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        myWins == false ? winningColor : AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
