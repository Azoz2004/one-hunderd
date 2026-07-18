import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart';
import 'package:one_hunderd/features/challenges/screens/challenge_competitive_stats_screen.dart';

/// شاشة سباق التحدي التنافسي — تعرض:
///  • نسبة الإنجاز المالي لكل لاعب
///  • سجل آخر إيداعات الخصم
///  • زر نكز الخصم (يكلف 10 مسكوكات، يومياً مرة واحدة)
class ChallengeCompetitiveScreen extends StatefulWidget {
  const ChallengeCompetitiveScreen({super.key});

  @override
  State<ChallengeCompetitiveScreen> createState() =>
      _ChallengeCompetitiveScreenState();
}

class _ChallengeCompetitiveScreenState
    extends State<ChallengeCompetitiveScreen> {
  bool _loadingPartner = true;

  double _partnerTotalSaved = 0;
  double _partnerFinancialGoal = 0;
  List<_DepositEntry> _partnerRecentDeposits = [];
  bool _poking = false;
  bool _depositsExpanded = false;

  static const _orange = Color(0xFFFF5722);
  static const _green = Color(0xFF4CAF50);
  static const _gold = Color(0xFFFFC107);

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

  void _listenToPartnerData() {
    if (!mounted) return;
    setState(() => _loadingPartner = true);

    final provider = context.read<SavingsProvider>();
    final partnerUid = provider.competitivePartnerUid;

    if (partnerUid == null) {
      if (mounted) setState(() => _loadingPartner = false);
      return;
    }

    _partnerSubscription?.cancel();
    _partnerSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(partnerUid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) {
        setState(() => _loadingPartner = false);
        return;
      }

      final data = doc.data() ?? {};
      final profile = data['user_profile_v1'] as Map<String, dynamic>? ?? {};
      final goal = (profile['financialGoal'] as num?)?.toDouble() ?? 0;

      final rawDeps = data['deposits_v1'] as List<dynamic>? ?? [];
      double total = 0;
      final deps = <_DepositEntry>[];

      for (final r in rawDeps) {
        try {
          final d = r as Map<String, dynamic>;
          final amount = (d['amount'] as num?)?.toDouble() ?? 0;
          total += amount;
          final dateStr = d['date'] as String?;
          if (dateStr != null) {
            deps.add(_DepositEntry(
              amount: amount,
              date: DateTime.tryParse(dateStr) ?? DateTime(2000),
            ));
          }
        } catch (_) {}
      }

      // Sort descending — most recent first
      deps.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _partnerTotalSaved = total;
          _partnerFinancialGoal = goal;
          _partnerRecentDeposits = deps;
          _loadingPartner = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loadingPartner = false);
    });
  }

  Future<void> _refreshData() async {
    _listenToPartnerData();
  }

  Future<void> _poke() async {
    if (_poking) return;
    setState(() => _poking = true);
    final provider = context.read<SavingsProvider>();
    try {
      await provider.pokePartner();
      if (mounted) {
        AppSnackbar.show(
          context: context,
          message: 'تم إرسال النكزة! 👇 خُصم 10 مسكوكات',
          isSuccess: true, // we treat successful poke as success
        );
      }
    } catch (e) {
      String msg = 'حدث خطأ، حاول مجدداً';
      if (e.toString().contains('insufficient_coins')) {
        msg = 'رصيدك من المسكوكات غير كافٍ (يلزم 10 مسكوكات 🪙)';
      } else if (e.toString().contains('already_poked_today')) {
        msg = 'لقد نكزت خصمك اليوم بالفعل! عد غداً 😄';
      }
      if (mounted) {
        AppSnackbar.show(
          context: context,
          message: msg,
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _poking = false);
    }
  }

  String _formatAmount(double v) {
    if (v == v.truncateToDouble()) return '${v.toInt()} JD';
    return '${v.toStringAsFixed(2)} JD';
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  double _pct(double saved, double goal) =>
      goal > 0 ? (saved / goal).clamp(0.0, 1.0) : 0;

  String _pctStr(double saved, double goal) =>
      goal > 0 ? '${(saved / goal * 100).clamp(0, 100).toStringAsFixed(1)}%' : '0%';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'سباق تنافسي ⚡',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: false,
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: true,
          leading: BackButton(color: AppColors.charcoal),
        ),
        body: Consumer<SavingsProvider>(
          builder: (context, provider, _) {
          final myName = provider.userProfile?.fullName ?? 'أنا';
          final partnerName =
              provider.competitivePartnerName ?? 'الخصم';
          final myAvatar = provider.avatarIndex;
          final partnerAvatar =
              provider.competitivePartnerAvatarIndex ?? 0;
          final mySaved = provider.totalSaved;
          final myGoal =
              provider.userProfile?.financialGoal ?? 0;
          final myCoins = provider.woodenCoins;

          final myPct = _pct(mySaved, myGoal);
          final partnerPct =
              _pct(_partnerTotalSaved, _partnerFinancialGoal);

          final iAmAhead = myPct >= partnerPct;

            return RefreshIndicator(
              onRefresh: _refreshData,
              color: _orange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── عنوان المواجهة ──────────────────────────────
                    _buildMatchupHeader(
                      myName: myName,
                      partnerName: partnerName,
                      myAvatar: myAvatar,
                      partnerAvatar: partnerAvatar,
                      iAmAhead: iAmAhead,
                    ),

                    const SizedBox(height: 20),

                    // ── نسبة الإنجاز المالي ─────────────────────────
                    _buildSectionTitle('الإنجاز المالي'),
                    const SizedBox(height: 12),
                    _buildFinancialProgress(
                      myName: myName,
                      mySaved: mySaved,
                      myGoal: myGoal,
                      partnerName: partnerName,
                      partnerSaved: _partnerTotalSaved,
                      partnerGoal: _partnerFinancialGoal,
                      myPct: myPct,
                      partnerPct: partnerPct,
                    ),

                    const SizedBox(height: 24),

                    // ── سجل إيداعات الخصم ───────────────────────────
                    _buildSectionTitle('سجل الإيداعات'),
                    const SizedBox(height: 12),
                    _buildPartnerDeposits(partnerName: partnerName),

                    const SizedBox(height: 24),

                    // ── زر نكز الخصم ────────────────────────────────
                    _buildPokeSection(
                      provider: provider,
                      partnerName: partnerName,
                      myCoins: myCoins,
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'اسحب لأسفل لتحديث بيانات الخصم',
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
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ChallengeCompetitiveStatsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded, color: _orange),
              label: const Text(
                'إحصائيات المواجهة التفصيلية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _orange,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.background,
                side: const BorderSide(color: _orange, width: 1.5),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────────


  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppColors.charcoal,
      ),
    );
  }

  // ── Matchup Header (avatars + VS) ──────────────────────────────────────────

  Widget _buildMatchupHeader({
    required String myName,
    required String partnerName,
    required int myAvatar,
    required int partnerAvatar,
    required bool iAmAhead,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PlayerChip(
            name: myName,
            avatarIndex: myAvatar,
            isWinning: iAmAhead,
            accentColor: _orange,
          ),
          Column(
            children: [
              const Text(
                'VS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  iAmAhead ? 'أنت في الصدارة 🏆' : 'الخصم يتقدم ⚡',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iAmAhead ? _green : _orange,
                  ),
                ),
              ),
            ],
          ),
          _PlayerChip(
            name: partnerName,
            avatarIndex: partnerAvatar,
            isWinning: !iAmAhead,
            accentColor: AppColors.charcoal,
          ),
        ],
      ),
    );
  }

  // ── Financial Progress Cards ───────────────────────────────────────────────

  Widget _buildFinancialProgress({
    required String myName,
    required double mySaved,
    required double myGoal,
    required String partnerName,
    required double partnerSaved,
    required double partnerGoal,
    required double myPct,
    required double partnerPct,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _FinancialBar(
            name: myName,
            saved: mySaved,
            goal: myGoal,
            pct: myPct,
            pctStr: _pctStr(mySaved, myGoal),
            color: _orange,
            formatAmount: _formatAmount,
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 20),
          _loadingPartner
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(color: _orange, strokeWidth: 2),
                  ),
                )
              : _FinancialBar(
                  name: partnerName,
                  saved: partnerSaved,
                  goal: partnerGoal,
                  pct: partnerPct,
                  pctStr: _pctStr(partnerSaved, partnerGoal),
                  color: AppColors.charcoal,
                  formatAmount: _formatAmount,
                ),
        ],
      ),
    );
  }

  // ── Partner Deposits Log ───────────────────────────────────────────────────

  Widget _buildPartnerDeposits({required String partnerName}) {
    if (_loadingPartner) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _depositsExpanded = !_depositsExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('📜', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سجل إيداعات $partnerName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _partnerRecentDeposits.isEmpty
                            ? 'لا يوجد إيداعات بعد'
                            : 'اضغط لعرض السجل كاملاً (${_partnerRecentDeposits.length} إيداع)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _depositsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
        if (_depositsExpanded) ...[
          const SizedBox(height: 8),
          if (_partnerRecentDeposits.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Center(
                child: Text(
                  'لا يوجد سجل إيداعات بعد',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: _partnerRecentDeposits.asMap().entries.map((entry) {
                  final i = entry.key;
                  final dep = entry.value;
                  final isLast = i == _partnerRecentDeposits.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('💰',
                                    style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatDate(dep.date),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              _formatAmount(dep.amount),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _orange,
                                  fontFamily: 'sans-serif'),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          color: AppColors.borderLight,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  // ── Poke Section ───────────────────────────────────────────────────────────

  Widget _buildPokeSection({
    required SavingsProvider provider,
    required String partnerName,
    required int myCoins,
  }) {
    final canPoke = provider.canPokeToday && myCoins >= 10;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canPoke
              ? [
                  const Color(0xFFFF5722).withValues(alpha: 0.1),
                  const Color(0xFFFF9800).withValues(alpha: 0.05),
                ]
              : [
                  AppColors.cardFill,
                  AppColors.cardFill,
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canPoke
              ? _orange.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👇', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نكز الخصم',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      'ذكّر $partnerName بالإيداع اليومي مقابل 10 مسكوكات',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('🪙',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$myCoins',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: canPoke && !_poking ? _poke : null,
              icon: _poking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.touch_app_rounded,
                      color: Colors.white),
              label: Text(
                !provider.canPokeToday
                    ? 'نكزت اليوم بالفعل ✓'
                    : myCoins < 10
                        ? 'مسكوكاتك غير كافية'
                        : 'نكز $partnerName الآن 👇',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canPoke ? _orange : AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: canPoke ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helper model
// ══════════════════════════════════════════════════════════════════════════════

class _DepositEntry {
  final double amount;
  final DateTime date;
  const _DepositEntry({required this.amount, required this.date});
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _PlayerChip extends StatelessWidget {
  final String name;
  final int avatarIndex;
  final bool isWinning;
  final Color accentColor;

  const _PlayerChip({
    required this.name,
    required this.avatarIndex,
    required this.isWinning,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWinning
                      ? accentColor
                      : AppColors.borderLight,
                  width: isWinning ? 3 : 1.5,
                ),
              ),
              child: ClipOval(
                child: FacelessAvatar(index: avatarIndex, size: 68),
              ),
            ),
            if (isWinning)
              const Positioned(
                top: -14,
                child: Text('👑', style: TextStyle(fontSize: 20)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: TextStyle(
              fontWeight: isWinning ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
              color: AppColors.charcoal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FinancialBar extends StatelessWidget {
  final String name;
  final double saved;
  final double goal;
  final double pct;
  final String pctStr;
  final Color color;
  final String Function(double) formatAmount;

  const _FinancialBar({
    required this.name,
    required this.saved,
    required this.goal,
    required this.pct,
    required this.pctStr,
    required this.color,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.charcoal,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pctStr,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 14,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مدخر: ${formatAmount(saved)}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              goal > 0 ? 'الهدف: ${formatAmount(goal)}' : 'الهدف غير محدد',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
