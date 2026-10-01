import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/core/widgets/custom_date_picker_modal.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/features/profile/models/user_profile.dart';

class FacelessAvatar extends StatelessWidget {
  final int index;
  final double size;
  const FacelessAvatar({super.key, required this.index, this.size = 56});

  static const _avatarAssets = [
    'assets/images/AVATAR.webp',     // Default avatar (index 0)
    'assets/images/AVATAR-3.webp',
    'assets/images/AVATAR-4.webp',
    'assets/images/AVATAR-5.webp',
    'assets/images/AVATAR-6.png',
    'assets/images/AVATAR-1.webp',
    'assets/images/AVATAR-2.webp',
    'assets/images/AVATAR-7.webp',
  ];

  @override
  Widget build(BuildContext context) {
    final i = index % _avatarAssets.length;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Transform.scale(
          scale: 1.16,
          child: Image.asset(
            _avatarAssets[i],
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) {
              return Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: AppColors.cardFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.textSecondary),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LinkedAvatars extends StatelessWidget {
  final int userAvatarIndex;
  final int partnerAvatarIndex;
  final double size;
  final double overlapMultiplier;

  const LinkedAvatars({
    super.key,
    required this.userAvatarIndex,
    required this.partnerAvatarIndex,
    this.size = 56,
    this.overlapMultiplier = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + size * (1 - overlapMultiplier),
      height: size,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardFill, width: 2),
              ),
              child: ClipOval(
                child: FacelessAvatar(index: partnerAvatarIndex, size: size),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardFill, width: 2.5),
              ),
              child: ClipOval(
                child: FacelessAvatar(index: userAvatarIndex, size: size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrossedSwordsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CrossedSwordsIcon({
    super.key,
    this.size = 14,
    this.color = AppColors.charcoal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _SwordsPainter(color: color),
      ),
    );
  }
}

class _SwordsPainter extends CustomPainter {
  final Color color;
  _SwordsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bladePaint = Paint()
      ..color = color
      ..strokeWidth = (w * 0.16).clamp(1.8, 3.5)
      ..strokeCap = StrokeCap.round;

    final guardPaint = Paint()
      ..color = color
      ..strokeWidth = (w * 0.16).clamp(1.8, 3.5)
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Sword 1 (\: Top-Left to Bottom-Right)
    canvas.drawLine(Offset(w * 0.12, h * 0.12), Offset(w * 0.82, h * 0.82), bladePaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.78), Offset(w * 0.78, h * 0.58), guardPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.85), w * 0.10, fillPaint);

    // Sword 2 (/: Top-Right to Bottom-Left)
    canvas.drawLine(Offset(w * 0.88, h * 0.12), Offset(w * 0.18, h * 0.82), bladePaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.78), Offset(w * 0.22, h * 0.58), guardPaint);
    canvas.drawCircle(Offset(w * 0.15, h * 0.85), w * 0.10, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SwordsPainter oldDelegate) => oldDelegate.color != color;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SavingsProvider>();
    if (provider.userProfile != null) {
      _loading = false;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() { _data = doc.data(); _loading = false; });
  }

  Future<void> _updateFirestore(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update(fields);
    await _loadData();
  }

  int _calcAge(String? iso) {
    if (iso == null) return 0;
    final bd = DateTime.tryParse(iso);
    if (bd == null) return 0;
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
    return age;
  }

  double _totalSaved() {
    final deps = _data?['deposits_v1'] as List<dynamic>? ?? [];
    return deps.fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));
  }

  int _totalDepositsCount() {
    final deps = _data?['deposits_v1'] as List<dynamic>? ?? [];
    return deps.length;
  }

  String _joinedSince() {
    final dt = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    if (dt == null) return '—';
    const months = [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  void _showAvatarPicker() {
    final currentIdx = _data?['avatarIndex'] as int? ?? 0;
    final provider = context.read<SavingsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: AppColors.cardFill,
      builder: (ctx) => SafeArea(
        child: _AvatarPickerSheet(
          currentIndex: currentIdx,
          onPick: (idx) async {
            Navigator.pop(ctx);
            provider.updateAvatarIndex(idx);
            await _updateFirestore({'avatarIndex': idx});
            if (mounted) {
              AppSnackbar.show(
                context: context,
                message: 'تم تحديث الصورة الرمزية بنجاح',
                isSuccess: true,
                isEdit: true,
              );
            }
          },
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final profile = _data?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final provider = context.read<SavingsProvider>();
    showAppDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: _EditProfileDialog(
            fullName: profile['fullName'] as String? ?? '',
            bio: profile['bio'] as String? ?? '',
            birthDate: profile['birthDate'] as String?,
            onSave: (name, bioText, bDate) async {
              final updated = Map<String, dynamic>.from(profile)
                ..['fullName'] = name
                ..['bio'] = bioText
                ..['birthDate'] = bDate;
              
              final newProfile = UserProfile.fromJson(updated);
              provider.updateProfile(newProfile);

              await _updateFirestore({'user_profile_v1': updated});
              if (ctx.mounted && mounted) {
                Navigator.pop(ctx);
                AppSnackbar.show(
                  context: context,
                  message: 'تم تحديث الملف الشخصي بنجاح',
                  isSuccess: true,
                  isEdit: true,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _showBadgeDetailModal({
    required String name,
    required String emoji,
    required String? imagePath,
    required bool isUnlocked,
    required String howToEarn,
    required String howEarnedText,
  }) {
    showAppDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (imagePath != null)
                      ClipOval(
                        child: Transform.scale(
                          scale: 1.1,
                          child: ColorFiltered(
                            colorFilter: isUnlocked
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      0.60, 0,
                                  ]),
                            child: Image.asset(imagePath, fit: BoxFit.contain),
                          ),
                        ),
                      )
                    else
                      Text(emoji, style: const TextStyle(fontSize: 44)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnlocked ? Colors.green : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      size: 14,
                      color: isUnlocked ? Colors.green : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? 'شارة مكتسبة 🎉' : 'شارة مقفولة 🔒',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isUnlocked ? Colors.green.shade800 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isUnlocked ? 'كيف حصلت عليها؟ 🌟' : 'طريقة فتح هذه الشارة 🎯',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isUnlocked ? howEarnedText : howToEarn,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حسناً، فهمت', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementDetailModal({
    required String title,
    required String emoji,
    required String? imagePath,
    required bool isUnlocked,
    required String howToEarn,
    required String howEarnedText,
  }) {
    showAppDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (imagePath != null)
                      ClipOval(
                        child: Transform.scale(
                          scale: 1.1,
                          child: ColorFiltered(
                            colorFilter: isUnlocked
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      0.60, 0,
                                  ]),
                            child: Image.asset(imagePath, fit: BoxFit.contain),
                          ),
                        ),
                      )
                    else
                      Text(emoji, style: const TextStyle(fontSize: 44)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnlocked ? Colors.green : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      size: 14,
                      color: isUnlocked ? Colors.green : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? 'إنجاز مكتسب 🎉' : 'إنجاز مقفول 🔒',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isUnlocked ? Colors.green.shade800 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isUnlocked ? 'كيف حققت هذا الإنجاز؟ 🌟' : 'طريقة فتح هذا الإنجاز 🎯',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isUnlocked ? howEarnedText : howToEarn,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حسناً، فهمت', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final userProf = provider.userProfile;

    if (_loading && userProf == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.charcoal)),
      );
    }

    final profile = _data?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final fullName = _data != null ? (profile['fullName'] as String? ?? 'مستخدم') : (userProf?.fullName ?? 'مستخدم');
    final contact = _data != null ? (profile['contact'] as String? ?? '') : (userProf?.contact ?? '');
    final bio = _data != null ? (profile['bio'] as String? ?? '') : (userProf?.bio ?? '');
    final birthDateStr = _data != null ? (profile['birthDate'] as String?) : userProf?.birthDate?.toIso8601String();
    final age = _calcAge(birthDateStr);
    final goal = _data != null ? ((profile['financialGoal'] as num?)?.toDouble() ?? 5050.0) : (userProf?.financialGoal ?? 5050.0);
    final maritalStatus = _data != null ? (profile['maritalStatus'] as String? ?? 'شاب') : (userProf?.maritalStatus ?? 'شاب');
    final goalType = _data != null ? (profile['goal'] as String? ?? 'بيت') : (userProf?.goal ?? 'بيت');
    final challengeType = _data != null ? (profile['challengeType'] as String? ?? 'فردي') : (userProf?.challengeType ?? 'فردي');
    
    final totalSaved = _data != null ? _totalSaved() : provider.totalSaved;
    final depositsCount = _data != null ? _totalDepositsCount() : provider.deposits.length;
    final streak = _data != null ? ((_data?['current_streak_v1'] as num?)?.toInt() ?? 0) : provider.currentStreak;
    final coins = _data != null ? ((_data?['wooden_coins_v1'] as num?)?.toInt() ?? 0) : provider.woodenCoins;
    final lifebuoys = _data != null ? ((_data?['lifebuoys_v1'] as num?)?.toInt() ?? 0) : provider.lifebuoys;
    final avatarIndex = _data != null ? ((_data?['avatarIndex'] as num?)?.toInt() ?? 0) : provider.avatarIndex;
    final progress = goal > 0 ? (totalSaved / goal).clamp(0.0, 1.0) : 0.0;
    
    final isCoop = provider.isCooperativeMode;
    final partnerAvatar = provider.partnerAvatarIndex;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.charcoal, fontSize: 18),
          ),
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.charcoal, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      body: RefreshIndicator(
        color: AppColors.charcoal,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card (Personal Info + Challenge Type + Bio) ──
              ProfileHeader(
                fullName: fullName,
                contact: contact,
                bio: bio,
                challengeType: challengeType,
                age: age,
                avatarIndex: avatarIndex,
                onAvatarTap: _showAvatarPicker,
                isCooperativeMode: isCoop,
                partnerAvatarIndex: partnerAvatar,
              ),
              const SizedBox(height: 16),

              // ── Edit Profile Button (Opens the compact dialog) ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                  label: const Text(
                    'تعديل الملف الشخصي',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Clean Account Overview ──
              const _SectionHeader(
                title: 'النظرة العامة',
                icon: Icons.pie_chart_outline_rounded,
              ),
              const SizedBox(height: 12),
              AccountOverview(
                totalSaved: totalSaved,
                goal: goal,
                progress: progress,
                streak: streak,
                coins: coins,
                lifebuoys: lifebuoys,
                depositsCount: depositsCount,
                maritalStatus: maritalStatus,
                goalType: goalType,
                challengeType: challengeType,
                joinedSince: _joinedSince(),
              ),
              const SizedBox(height: 24),

              // ── Weekly Badges ──
              const _SectionHeader(
                title: 'شارات الأسبوع',
                icon: Icons.military_tech_outlined,
              ),
              const SizedBox(height: 12),
              BadgesSection(
                streakDays: provider.currentStreak,
                onBadgeTap: ({
                  required name,
                  required emoji,
                  required imagePath,
                  required isUnlocked,
                  required howToEarn,
                  required howEarnedText,
                }) {
                  _showBadgeDetailModal(
                    name: name,
                    emoji: emoji,
                    imagePath: imagePath,
                    isUnlocked: isUnlocked,
                    howToEarn: howToEarn,
                    howEarnedText: howEarnedText,
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Achievements ──
              const _SectionHeader(
                title: 'الإنجازات',
                icon: Icons.emoji_events_outlined,
              ),
              const SizedBox(height: 12),
              AchievementsSection(
                depositsCount: depositsCount,
                streakDays: provider.currentStreak,
                financialGoal: goal,
                totalSaved: totalSaved,
                woodenCoins: coins,
                onTap: ({
                  required title,
                  required emoji,
                  required imagePath,
                  required isUnlocked,
                  required howToEarn,
                  required howEarnedText,
                }) {
                  _showAchievementDetailModal(
                    title: title,
                    emoji: emoji,
                    imagePath: imagePath,
                    isUnlocked: isUnlocked,
                    howToEarn: howToEarn,
                    howEarnedText: howEarnedText,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─── Section Header Widget ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 20, color: AppColors.charcoal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────
class ProfileHeader extends StatelessWidget {
  final String fullName, contact, bio, challengeType;
  final int age, avatarIndex;
  final VoidCallback onAvatarTap;
  final bool isCooperativeMode;
  final int? partnerAvatarIndex;

  const ProfileHeader({
    super.key,
    required this.fullName,
    required this.contact,
    required this.bio,
    required this.challengeType,
    required this.age,
    required this.avatarIndex,
    required this.onAvatarTap,
    this.isCooperativeMode = false,
    this.partnerAvatarIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info (Right aligned text)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.alternate_email_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            contact,
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Organized Info Chips Row
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isCooperativeMode || challengeType == 'تعاوني')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_rounded, size: 13, color: Color(0xFF1565C0)),
                                SizedBox(width: 4),
                                Text(
                                  'تعاوني',
                                  style: TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        if (challengeType == 'تنافسي')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFF5722)),
                                SizedBox(width: 4),
                                Text(
                                  'تنافسي',
                                  style: TextStyle(color: Color(0xFFFF5722), fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        if (challengeType == 'فردي' || (!isCooperativeMode && challengeType != 'تعاوني' && challengeType != 'تنافسي'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_rounded, size: 13, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'فردي',
                                  style: TextStyle(color: AppColors.charcoal, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        if (age > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cake_rounded, size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '$age سنة',
                                  style: const TextStyle(color: AppColors.charcoal, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Avatar on LEFT (in RTL)
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  children: [
                    if (isCooperativeMode && partnerAvatarIndex != null)
                      LinkedAvatars(
                        userAvatarIndex: avatarIndex,
                        partnerAvatarIndex: partnerAvatarIndex!,
                        size: 76,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.15), width: 2),
                        ),
                        child: ClipOval(child: FacelessAvatar(index: avatarIndex, size: 76)),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.charcoal,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardFill, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Clean Bio Box without quote icons or long instructional texts
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'النبذة العامة',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bio.trim().isNotEmpty ? bio.trim() : 'لا توجد نبذة عامة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: bio.trim().isNotEmpty ? AppColors.charcoal : AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
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

// ─── Avatar Picker Sheet ───────────────────────────────────────────────────
class _AvatarPickerSheet extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onPick;
  const _AvatarPickerSheet({required this.currentIndex, required this.onPick});

  List<int> get _orderedIndices {
    final activeIdx = currentIndex % 8;
    final all = List<int>.generate(8, (i) => i);
    all.removeWhere((i) => i == activeIdx);
    final reversedOthers = all.reversed.toList();
    return [activeIdx, ...reversedOthers];
  }

  @override
  Widget build(BuildContext context) {
    final indices = _orderedIndices;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('اختر صورة الملف الشخصي', textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.charcoal)),
          const SizedBox(height: 4),
          const Text('اضغط على أي شخصية لاختيار صورتك', textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: indices.length,
            itemBuilder: (_, gridIdx) {
              final avatarIdx = indices[gridIdx];
              final selected = avatarIdx == (currentIndex % 8);
              return GestureDetector(
                onTap: () => onPick(avatarIdx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.charcoal : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(child: FacelessAvatar(index: avatarIdx, size: 72)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Edit Profile Dialog ──────────────────────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  final String fullName, bio;
  final String? birthDate;
  final Future<void> Function(String, String, String?) onSave;
  
  const _EditProfileDialog({
    required this.fullName,
    required this.bio,
    required this.birthDate,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameCtrl, _bioCtrl;
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.fullName);
    _bioCtrl = TextEditingController(text: widget.bio);
    if (widget.birthDate != null) _birthDate = DateTime.tryParse(widget.birthDate!);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _pickDate() {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 20, 6, 15);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return CustomDatePickerModal(
          initialDate: initialDate,
          onConfirm: (d) {
            setState(() => _birthDate = d);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'تعديل الملف الشخصي',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.charcoal),
          ),
          const SizedBox(height: 20),
          
          // Name Field
          TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: _dec('الاسم الكامل', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 14),

          // Bio Field
          TextField(
            controller: _bioCtrl,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            maxLength: 120,
            decoration: _dec('النبذة العامة', Icons.article_outlined),
          ),
          const SizedBox(height: 14),

          // Birth Date Picker
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.cake_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'
                        : 'اختر تاريخ الميلاد',
                    style: TextStyle(
                      color: _birthDate != null ? AppColors.charcoal : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : () async {
                    if (_nameCtrl.text.trim().isEmpty) return;
                    setState(() => _saving = true);
                    await widget.onSave(
                      _nameCtrl.text.trim(),
                      _bioCtrl.text.trim(),
                      _birthDate?.toIso8601String(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5)),
  );
}

// ─── Clean Account Overview Section ─────────────────────────────────────────
class AccountOverview extends StatelessWidget {
  final double totalSaved, goal, progress;
  final int streak, coins, lifebuoys, depositsCount;
  final String maritalStatus, goalType, challengeType, joinedSince;

  const AccountOverview({
    super.key,
    required this.totalSaved,
    required this.goal,
    required this.progress,
    required this.streak,
    required this.coins,
    this.lifebuoys = 0,
    this.depositsCount = 0,
    this.maritalStatus = '',
    this.goalType = '',
    this.challengeType = '',
    required this.joinedSince,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    final remainingAmount = (goal - totalSaved).clamp(0.0, goal);
    final dailyAvg = streak > 0 ? (totalSaved / streak) : totalSaved;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Progress Circular Radial Gauge ──
          Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.charcoal),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                        ),
                        const Text(
                          'من الهدف',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverviewAmountRow(
                      title: 'المجموع المدخر',
                      amount: totalSaved % 1 == 0 ? '${totalSaved.toInt()} JD' : '${totalSaved.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} JD',
                      amountColor: AppColors.charcoal,
                    ),
                    const SizedBox(height: 8),
                    _OverviewAmountRow(
                      title: 'الهدف المالي',
                      amount: goal % 1 == 0 ? '${goal.toInt()} JD' : '${goal.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} JD',
                      amountColor: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    _OverviewAmountRow(
                      title: 'المتبقي',
                      amount: remainingAmount % 1 == 0 ? '${remainingAmount.toInt()} JD' : '${remainingAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} JD',
                      amountColor: remainingAmount == 0 ? Colors.green : Colors.deepOrange,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 20),

          // ── 3 Main Core Metrics Row (Removed duplicate "الرصيد") ──
          Row(
            children: [
              _MiniStat(
                icon: Icons.local_fire_department_rounded,
                label: 'الالتزام',
                value: '$streak',
                iconColor: Colors.deepOrange,
              ),
              _Divider(),
              _MiniStat(
                icon: Icons.generating_tokens_rounded,
                label: 'العملات',
                value: '$coins',
                iconColor: Colors.amber.shade700,
              ),
              _Divider(),
              _MiniStat(
                icon: Icons.health_and_safety,
                label: 'أطواق النجاة',
                value: '$lifebuoys',
                iconColor: Colors.teal,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // ── Extended Insights Grid (2x2) ──
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.insights_rounded,
                  label: 'متوسط الادخار اليومي',
                  value: dailyAvg % 1 == 0 ? '${dailyAvg.toInt()} JD/يوم' : '${dailyAvg.toStringAsFixed(1)} JD/يوم',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'إجمالي الإيداعات',
                  value: '$depositsCount إيداع',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.stars_rounded,
                  label: 'هدفك',
                  value: goalType.isNotEmpty ? goalType : 'بيت',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'عضو منذ',
                  value: joinedSince,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewAmountRow extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;

  const _OverviewAmountRow({
    required this.title,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            color: amountColor,
            fontWeight: FontWeight.w800,
            fontFamily: 'sans-serif',
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 18, color: AppColors.charcoal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'sans-serif',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor;
  const _MiniStat({required this.icon, required this.label, required this.value, this.iconColor = AppColors.charcoal});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 20, color: iconColor),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.charcoal), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: AppColors.borderLight);
}

// ─── Badges Section (RTL Horizontal List) ──────────────────────────────────
class BadgesSection extends StatelessWidget {
  final void Function({
    required String name,
    required String emoji,
    required String? imagePath,
    required bool isUnlocked,
    required String howToEarn,
    required String howEarnedText,
  }) onBadgeTap;

  final int streakDays;

  const BadgesSection({
    super.key,
    required this.onBadgeTap,
    this.streakDays = 0,
  });

  static const _badges = [
    (
      '🔥',
      'سبعة أيام',
      'قم بإجراء إيداع يومي واحتفظ بالستريك لمدة 7 أيام متتالية دون انقطاع.',
      'تهانينا! لقد حافظت على الستريك 7 أيام متتالية وأثبت التزامك التام في التحدي!',
      'assets/images/SIGNAL-1.webp',
      7
    ),
    (
      '⚡',
      'مدخر سريع',
      'قم بإجراء إيداعك اليومي خلال الساعة الأولى من يومك واستمر لـ 5 أيام متتالية.',
      'إنجاز رائع! قمت بالادخار السريع في أول اليوم لـ 5 أيام واحتفظت بحماسك!',
      'assets/images/SIGNAL-2.webp',
      5
    ),
    (
      '🌙',
      'بومة الليل',
      'قم بتسجيل إيداعاتك في التحدي المسائي بعد الساعة 10 مساءً لمدة 3 أيام.',
      'عمل ممتاز! أظهرت إصرارك في الادخار المسائي وتجاوزت التحديات لـ 3 أيام!',
      'assets/images/SIGNAL-3.webp',
      3
    ),
    (
      '💎',
      'المدخر الماسي',
      'واصل الادخار والالتزام التام في التحدي لمدة 30 يوماً متواصلة دون انقطاع.',
      'أنت بطل الادخار الماسي! أكملت 30 يوماً متواصلة من الانضباط والتحدي الإيجابي!',
      'assets/images/SIGNAL-5.webp',
      30
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _badges.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final b = _badges[i];
            final unlocked = streakDays >= b.$6;
            return GestureDetector(
              onTap: () => onBadgeTap(
                name: b.$2,
                emoji: b.$1,
                imagePath: b.$5,
                isUnlocked: unlocked,
                howToEarn: b.$3,
                howEarnedText: b.$4,
              ),
              child: _LockedBadge(
                emoji: b.$1,
                label: b.$2,
                imagePath: b.$5,
                isUnlocked: unlocked,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  final String emoji, label;
  final String? imagePath;
  final bool isUnlocked;

  const _LockedBadge({
    required this.emoji,
    required this.label,
    this.imagePath,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    double scaleFactor = 1.0;
    if (imagePath != null) {
      if (imagePath!.contains('SIGNAL-1')) {
        scaleFactor = 1.25;
      } else if (imagePath!.contains('SIGNAL-2')) {
        scaleFactor = 0.88;
      } else if (imagePath!.contains('SIGNAL-3')) {
        scaleFactor = 1.22;
      } else if (imagePath!.contains('SIGNAL-4') || imagePath!.contains('SIGNAL-5')) {
        scaleFactor = 0.86;
      }
    }

    // Grayscale matrix for locked state, vibrant color for unlocked state
    final ColorFilter colorFilter = isUnlocked
        ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
        : const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.60, 0,
          ]);

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: imagePath != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Transform.scale(
                          scale: scaleFactor,
                          child: ColorFiltered(
                            colorFilter: colorFilter,
                            child: Image.asset(
                              imagePath!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Text(
                                emoji,
                                style: TextStyle(fontSize: 26, color: AppColors.charcoal.withValues(alpha: 0.2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isUnlocked)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.cardFill,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.charcoal.withValues(alpha: 0.03),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 26, color: AppColors.charcoal.withValues(alpha: 0.2))),
                        if (!isUnlocked)
                          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isUnlocked ? FontWeight.w800 : FontWeight.w600,
              color: isUnlocked ? AppColors.charcoal : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Achievements Section (RTL Horizontal List) ──────────────────────────────
class AchievementsSection extends StatelessWidget {
  final void Function({
    required String title,
    required String emoji,
    required String? imagePath,
    required bool isUnlocked,
    required String howToEarn,
    required String howEarnedText,
  }) onTap;

  final int depositsCount;
  final int streakDays;
  final double financialGoal;
  final double totalSaved;
  final int woodenCoins;

  const AchievementsSection({
    super.key,
    required this.onTap,
    this.depositsCount = 0,
    this.streakDays = 0,
    this.financialGoal = 0.0,
    this.totalSaved = 0.0,
    this.woodenCoins = 0,
  });

  static const _achievements = [
    (
      '🏆',
      'أول إيداع',
      'قم بإجراء وتسجيل أول إيداع لك في خطة التحدي لفتح هذا الإنجاز!',
      'تهانينا! قمت بتسجيل أول خطوة لك في ادخارك وانطلقت بنجاح في التحدي!',
      'assets/images/ACHIEVEMENT-1.webp',
      'first_deposit'
    ),
    (
      '🎯',
      'حدد الهدف',
      'قم بتحديد وتنظيم هدف مالي واضح لخطة ادخارك لفتح هذا الإنجاز!',
      'إنجاز ممتاز! قمت بتحديد هدفك المالي بوضوح وتخطيط خطوتك الادخارية القادمة!',
      'assets/images/ACHIEVEMENT-2.webp',
      'set_goal'
    ),
    (
      '📅',
      'بطل 30 يوماً',
      'حافظ على الستريك والإيداع المستمر لمدة 30 يوماً متواصلة دون انقطاع لفتح هذا الإنجاز!',
      'أنت بطل الانضباط! حافظت على التزامك والادخار اليومي لمدة 30 يوماً متواصلة!',
      'assets/images/ACHIEVEMENT-3.webp',
      'streak_30'
    ),
    (
      '💰',
      'نصف الطريق',
      'قم بتوفير وادخار 50% من إجمالي هدفك المالي المستهدف لفتح هذا الإنجاز!',
      'عمل عظيم! قطعت نصف الطريق نحو تحقيق هدفك المالي بنجاح واقتدار!',
      'assets/images/ACHIEVEMENT-4.webp',
      'halfway'
    ),
    (
      '🚀',
      'اكتمال التحدي',
      'أكمل 100 يوم أو 100 إيداع في التحدي بنجاح تام لفتح هذا الإنجاز!',
      'إنجاز استثنائي! أكملت تحدي المائة يوم بنجاح وتفوق باهر!',
      'assets/images/ACHIEVEMENT-5.webp',
      'complete_challenge'
    ),
    (
      '👑',
      'ملك العملات',
      'اجمع واكسب 1000 عملة خشبية من خلال إنجازاتك والتزامك لفتح هذا الإنجاز!',
      'يا لك من ملك! جمعت أكثر من 1000 عملة خشبية بفضل نشاطك والتزامك المستمر!',
      'assets/images/ACHIEVEMENT-6.webp',
      'coin_king'
    ),
  ];

  bool _checkUnlocked(String key) {
    switch (key) {
      case 'first_deposit':
        return depositsCount >= 1;
      case 'set_goal':
        return financialGoal > 0;
      case 'streak_30':
        return streakDays >= 30;
      case 'halfway':
        return financialGoal > 0 && (totalSaved / financialGoal) >= 0.5;
      case 'complete_challenge':
        return depositsCount >= 100 || streakDays >= 100;
      case 'coin_king':
        return woodenCoins >= 1000;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _achievements.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final a = _achievements[i];
            final unlocked = _checkUnlocked(a.$6);
            return GestureDetector(
              onTap: () => onTap(
                title: a.$2,
                emoji: a.$1,
                imagePath: a.$5,
                isUnlocked: unlocked,
                howToEarn: a.$3,
                howEarnedText: a.$4,
              ),
              child: _LockedAchievement(
                emoji: a.$1,
                label: a.$2,
                imagePath: a.$5,
                isUnlocked: unlocked,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LockedAchievement extends StatelessWidget {
  final String emoji, label;
  final String? imagePath;
  final bool isUnlocked;

  const _LockedAchievement({
    required this.emoji,
    required this.label,
    this.imagePath,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorFilter colorFilter = isUnlocked
        ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
        : const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.60, 0,
          ]);

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: imagePath != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Transform.scale(
                          scale: 1.1,
                          child: ColorFiltered(
                            colorFilter: colorFilter,
                            child: Image.asset(
                              imagePath!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Text(
                                emoji,
                                style: TextStyle(fontSize: 26, color: AppColors.charcoal.withValues(alpha: 0.2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isUnlocked)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.cardFill,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.charcoal.withValues(alpha: 0.03),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 26, color: AppColors.charcoal.withValues(alpha: 0.2))),
                        if (!isUnlocked)
                          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isUnlocked ? FontWeight.w800 : FontWeight.w600,
              color: isUnlocked ? AppColors.charcoal : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
