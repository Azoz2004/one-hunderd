import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:one_hunderd/features/friends/services/friends_service.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart'; // FacelessAvatar, AccountOverview

class UserProfileDetailScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final int? initialAvatarIndex;
  final String? initialEmail;

  const UserProfileDetailScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatarIndex,
    this.initialEmail,
  });

  @override
  State<UserProfileDetailScreen> createState() => _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> {
  Map<String, dynamic>? _userData;
  FriendshipStatus _status = FriendshipStatus.none;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _userData = doc.data();
          _status = status;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() => _actionLoading = true);
    try {
      await FriendsService.sendFriendRequest(widget.userId);
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _status = status;
          _actionLoading = false;
        });
        AppSnackbar.show(
          context: context,
          message: 'تم إرسال طلب الصداقة بنجاح',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر إرسال طلب الصداقة: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _cancelFriendRequest() async {
    setState(() => _actionLoading = true);
    try {
      await FriendsService.cancelFriendRequest(widget.userId);
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _status = status;
          _actionLoading = false;
        });
        AppSnackbar.show(
          context: context,
          message: 'تم إلغاء طلب الصداقة بنجاح',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر إلغاء طلب الصداقة: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    setState(() => _actionLoading = true);
    try {
      final reqs = await FriendsService.getIncomingRequests();
      final req = reqs.firstWhere(
        (r) => (r['user'] as FriendUser).uid == widget.userId,
        orElse: () => {},
      );
      if (req.isNotEmpty) {
        await FriendsService.acceptFriendRequest(
          req['requestId'] as String,
          widget.userId,
        );
      }
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _status = status;
          _actionLoading = false;
        });
        AppSnackbar.show(
          context: context,
          message: 'تم قبول طلب الصداقة بنجاح',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر قبول طلب الصداقة: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _rejectFriendRequest() async {
    setState(() => _actionLoading = true);
    try {
      final reqs = await FriendsService.getIncomingRequests();
      final req = reqs.firstWhere(
        (r) => (r['user'] as FriendUser).uid == widget.userId,
        orElse: () => {},
      );
      if (req.isNotEmpty) {
        await FriendsService.rejectFriendRequest(req['requestId'] as String);
      }
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _status = status;
          _actionLoading = false;
        });
        AppSnackbar.show(
          context: context,
          message: 'تم رفض طلب الصداقة',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر رفض طلب الصداقة: $e',
          isSuccess: false,
        );
      }
    }
  }

  void _confirmUnfriend(BuildContext context) {
    final profile = _userData?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final fullName = profile['fullName'] as String? ?? widget.initialName ?? 'المستخدم';

    showAppDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'إلغاء الصداقة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من إلغاء الصداقة مع $fullName؟',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'تراجع',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); // close dialog
                _performUnfriend();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'نعم، إلغاء الصداقة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUnfriend() async {
    setState(() => _actionLoading = true);
    try {
      await FriendsService.unfriend(widget.userId);
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _status = status;
          _actionLoading = false;
        });
        AppSnackbar.show(
          context: context,
          message: 'تم إلغاء الصداقة بنجاح',
          isSuccess: false,
          isDelete: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر إلغاء الصداقة: $e',
          isSuccess: false,
        );
      }
    }
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
                      isUnlocked ? 'كيف حصل عليها؟ 🌟' : 'طريقة فتح هذه الشارة 🎯',
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
                      isUnlocked ? 'كيف حقق هذا الإنجاز؟ 🌟' : 'طريقة فتح هذا الإنجاز 🎯',
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

  double _totalSaved() {
    final deps = _userData?['deposits_v1'] as List<dynamic>? ?? [];
    return deps.fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));
  }

  String _joinedSince() {
    final ts = _userData?['createdAt'] as Timestamp?;
    DateTime? dt = ts?.toDate();

    if (dt == null) {
      // بديل ذكي: البحث عن تاريخ أقدم عملية إدخار في قائمة الإيداعات
      final deps = _userData?['deposits_v1'] as List<dynamic>? ?? [];
      if (deps.isNotEmpty) {
        DateTime? earliest;
        for (final d in deps) {
          final dateStr = d['date'] as String?;
          if (dateStr != null) {
            final parsed = DateTime.tryParse(dateStr);
            if (parsed != null) {
              if (earliest == null || parsed.isBefore(earliest)) {
                earliest = parsed;
              }
            }
          }
        }
        dt = earliest;
      }
    }

    if (dt == null) return '—';
    
    const months = [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final initialName = widget.initialName ?? 'مستخدم';
    final initialAvatarIndex = widget.initialAvatarIndex ?? 0;
    final initialEmail = widget.initialEmail ?? '';

    final profile = _userData?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final fullName = profile['fullName'] as String? ?? initialName;
    final contact = profile['contact'] as String? ?? initialEmail;
    final bio = profile['bio'] as String? ?? '';
    final birthDateStr = profile['birthDate'] as String?;
    final birthDate = birthDateStr != null ? DateTime.tryParse(birthDateStr) : null;
    int? age;
    if (birthDate != null) {
      age = DateTime.now().year - birthDate.year;
      if (DateTime.now().month < birthDate.month || (DateTime.now().month == birthDate.month && DateTime.now().day < birthDate.day)) {
        age--;
      }
    }
    final goal = (profile['financialGoal'] as num?)?.toDouble() ?? 5050.0;
    final totalSaved = _totalSaved();
    final streak = _userData?['current_streak_v1'] as int? ?? 0;
    final coins = _userData?['wooden_coins_v1'] as int? ?? 0;
    final avatarIndex = _userData?['avatarIndex'] as int? ?? initialAvatarIndex;
    final progress = goal > 0 ? (totalSaved / goal).clamp(0.0, 1.0) : 0.0;
    final depsList = _userData?['deposits_v1'] as List<dynamic>? ?? [];
    final depositsCount = depsList.length;

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
          backgroundColor: AppColors.background,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.charcoal, size: 20),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          const Text('تعذّر تحميل البيانات', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadAll,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.charcoal,
                    onRefresh: _loadAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header Card ──
                          Container(
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
                                    // ── Name & Info on RIGHT ──
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
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
                                              ),
                                              if (_status == FriendshipStatus.friends) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.green.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_circle_rounded, size: 11, color: AppColors.green),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'صديق',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
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
                                          // ── Info Chips ──
                                          Wrap(
                                            alignment: WrapAlignment.start,
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              if (profile['challengeType'] == 'تعاوني')
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
                                              if (profile['challengeType'] == 'تنافسي')
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
                                              if (profile['challengeType'] == 'فردي' || (profile['challengeType'] != 'تعاوني' && profile['challengeType'] != 'تنافسي'))
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
                                              if (age != null && age > 0)
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
                                    // ── Avatar on LEFT (in RTL) ──
                                    ClipOval(child: FacelessAvatar(index: avatarIndex, size: 76)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1, color: AppColors.borderLight),
                                const SizedBox(height: 12),
                                // ── Bio Box aligned to RIGHT ──
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
                          ),
                          const SizedBox(height: 20),

                          // ── Friendship Action Button ──
                          _buildFriendshipActionSection(context),
                          const SizedBox(height: 24),

                          // ── Account Overview ──
                          const Text(
                            'نظرة عامة',
                            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          const SizedBox(height: 12),
                          AccountOverview(
                            totalSaved: totalSaved,
                            goal: goal,
                            progress: progress,
                            streak: streak,
                            coins: coins,
                            joinedSince: _joinedSince(),
                          ),
                          const SizedBox(height: 24),

                          // ── Weekly Badges ──
                          const Text(
                            'شارات الأسبوع',
                            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          const SizedBox(height: 12),
                          BadgesSection(
                            streakDays: streak,
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
                          const Text(
                            'الإنجازات',
                            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          const SizedBox(height: 12),
                          AchievementsSection(
                            depositsCount: depositsCount,
                            streakDays: streak,
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

  Widget _buildFriendshipActionSection(BuildContext context) {
    if (_actionLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: AppColors.charcoal, strokeWidth: 2.5),
          ),
        ),
      );
    }

    switch (_status) {
      case FriendshipStatus.friends:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => _confirmUnfriend(context),
            icon: const Icon(Icons.person_remove_rounded, size: 20, color: AppColors.error),
            label: const Text(
              'إلغاء الصداقة',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );

      case FriendshipStatus.pending:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _cancelFriendRequest,
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
            label: const Text(
              'إلغاء طلب الصداقة المعلق',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );

      case FriendshipStatus.received:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _acceptFriendRequest,
                icon: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                label: const Text('قبول طلب الصداقة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _rejectFriendRequest,
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
                label: const Text('رفض الطلب', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );

      case FriendshipStatus.none:
      default:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _sendFriendRequest,
            icon: const Icon(Icons.person_add_rounded, size: 20, color: Colors.white),
            label: const Text(
              'إضافة صديق',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );
    }
  }
}
