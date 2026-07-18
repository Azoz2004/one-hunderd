import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart'; // for FacelessAvatar

class ChallengeDetailsScreen extends StatelessWidget {
  const ChallengeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    
    if (!provider.isCooperativeMode || myUid == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'لا يوجد تحدي تعاوني نشط',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final partnerUid = provider.partnerUid;
    final partnerName = provider.partnerName ?? 'صديق';
    final partnerAvatar = provider.partnerAvatarIndex ?? 0;
    final myAvatar = provider.avatarIndex;
    final myName = provider.userProfile?.fullName ?? 'أنا';

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

    final totalSaved = myContribution + partnerContribution;
    final financialGoal = provider.userProfile?.financialGoal ?? 5050.0;
    final goalProgress = (financialGoal > 0 ? (totalSaved / financialGoal).clamp(0.0, 1.0) : 0.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تفاصيل التحدي التعاوني', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.charcoal, fontFamily: 'Tajawal')),
          centerTitle: false,
          backgroundColor: AppColors.background,
          elevation: 0,
          titleSpacing: 0,
          leading: const BackButton(color: AppColors.charcoal),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    // ── بطاقة الإجمالي ──
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'المجموع المشترك',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalSaved.toStringAsFixed(2)} JD',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'sans-serif'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الهدف: ${financialGoal.toStringAsFixed(2)} JD',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'sans-serif'),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: goalProgress,
                              minHeight: 10,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── مساهمات الطرفين ──
                    Row(
                      children: [
                        Expanded(
                          child: _ContributorCard(
                            name: myName,
                            avatarIndex: myAvatar,
                            contribution: myContribution,
                            isMe: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ContributorCard(
                            name: partnerName,
                            avatarIndex: partnerAvatar,
                            contribution: partnerContribution,
                            isMe: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'سجل الإيداعات المشتركة',
                        style: TextStyle(color: AppColors.charcoal, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            
            // ── قائمة الإيداعات ──
            if (deposits.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'لا توجد إيداعات حتى الآن.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dep = deposits[deposits.length - 1 - index]; // reverse chronological
                      final isMine = dep.depositedBy == myUid;
                      final depName = isMine ? myName : partnerName;
                      final depAvatar = isMine ? myAvatar : partnerAvatar;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            ClipOval(child: FacelessAvatar(index: depAvatar, size: 40)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    depName,
                                    style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('yyyy-MM-dd • hh:mm a').format(dep.date),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+${dep.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isMine ? const Color(0xFF4CAF50) : const Color(0xFF388E3C),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: deposits.length,
                  ),
                ),
              ),
              
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _ContributorCard extends StatelessWidget {
  final String name;
  final int avatarIndex;
  final double contribution;
  final bool isMe;

  const _ContributorCard({
    required this.name,
    required this.avatarIndex,
    required this.contribution,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          ClipOval(child: FacelessAvatar(index: avatarIndex, size: 48)),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            isMe ? 'مساهمتك' : 'مساهمة الشريك',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            '${contribution.toStringAsFixed(2)} JD',
            style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'sans-serif'),
          ),
        ],
      ),
    );
  }
}
