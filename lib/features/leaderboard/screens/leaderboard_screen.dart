import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart';

enum _Mode { streak, road, club }

// ─── Medal colours ─────────────────────────────────────────────────────────────
const _r1Grad = [Color(0xFF3D2010), Color(0xFF6B3A1F)]; // ebony
const _r2Grad = [Color(0xFF4A2E10), Color(0xFF8B5A28)]; // walnut
const _r3Grad = [Color(0xFF6B5010), Color(0xFFC49A40)]; // oak
const _r1Border = Color(0xFF8B5A28);
const _r2Border = Color(0xFFB07840);
const _r3Border = Color(0xFFD4AA50);

List<Color> _rankGrad(int r) => r == 1 ? _r1Grad : r == 2 ? _r2Grad : _r3Grad;
Color _rankBorder(int r) => r == 1 ? _r1Border : r == 2 ? _r2Border : _r3Border;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LS();
}

class _LS extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          titleSpacing: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _r3Grad),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('لوحة الصدارة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                controller: _tc,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.charcoal, Color(0xFF4A3828)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
                padding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: 'الالتزام'),
                  Tab(text: 'الساعون للمئة'),
                  Tab(text: 'نادي المئة'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tc,
          children: [
            _LeaderTab(mode: _Mode.streak, uid: _uid),
            _LeaderTab(mode: _Mode.road,   uid: _uid),
            _LeaderTab(mode: _Mode.club,   uid: _uid),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _LeaderTab extends StatefulWidget {
  final _Mode mode; final String uid;
  const _LeaderTab({required this.mode, required this.uid});
  @override State<_LeaderTab> createState() => _LTS();
}

class _LTS extends State<_LeaderTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int  _myRank = -1;
  Map<String, dynamic>? _myData;
  String? _error;

  @override bool get wantKeepAlive => true;
  @override void initState() { super.initState(); _fetch(); }

  String _cleanName(String name) {
    if (name.contains(' 🤝 ')) {
      return name.split(' 🤝 ').first.trim();
    }
    return name.trim();
  }

  int _days(Map<String, dynamic> u) {
    // نستخدم الحقل المحسوب أولاً (أسرع)، وإلا نحسبه من المصفوفة كـ fallback
    final cached = u['completed_days_count'] as int?;
    if (cached != null) return cached;
    return (u['deposits_v1'] as List? ?? []).length;
  }

  bool _isComplete(Map<String, dynamic> u) =>
      (u['is_complete_v1'] as bool? ?? false) || _days(u) >= 100;

  /// يبني الـ Query المناسب لكل تبويب ويجلب البيانات من الخادم مباشرة
  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      List<Map<String, dynamic>> users;
      final col = FirebaseFirestore.instance.collection('users');

      switch (widget.mode) {
        // ── تبويب الالتزام: مرتّب بـ current_streak من الخادم ─────────────────
        case _Mode.streak:
          final snap = await col
              .orderBy('current_streak_v1', descending: true)
              .limit(100)
              .get();
          users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

        // ── الساعون للمئة: لم يكملوا 100 يوم، مرتّبون بعدد الأيام ──────────
        case _Mode.road:
          final snap = await col
              .where('is_complete_v1', isEqualTo: false)
              .orderBy('completed_days_count', descending: true)
              .limit(100)
              .get();
          // fallback: بعض المستخدمين القدامى قد لا يملكون is_complete_v1 بعد
          final snapFallback = await col
              .where('is_complete_v1', isNull: true)
              .orderBy('completed_days_count', descending: true)
              .limit(50)
              .get();
          final allDocs = {...{for (final d in snap.docs) d.id: d}, ...{for (final d in snapFallback.docs) d.id: d}};
          users = allDocs.values.map((d) => {'id': d.id, ...d.data()}).toList();
          users = users.where((u) => !_isComplete(u)).toList();
          users.sort((a, b) => _days(b).compareTo(_days(a)));
          if (users.length > 100) users = users.sublist(0, 100);

        // ── نادي المئة: أكملوا التحدي، مرتّبون بتاريخ الإتمام ───────────────
        case _Mode.club:
          final snap = await col
              .where('is_complete_v1', isEqualTo: true)
              .orderBy('completedAt')
              .limit(100)
              .get();
          users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      // ── دمج الشركاء التعاونيين في صف واحد لإزالة التكرار ──────────────────────────
      final List<Map<String, dynamic>> mergedUsers = [];
      final Set<String> processedSessionIds = {};

      for (var u in users) {
        final profile = u['user_profile_v1'] as Map<String, dynamic>? ?? {};
        final isCoop = profile['challengeType'] == 'تعاوني';
        final sessionId = u['activeSessionId'] as String?;

        if (isCoop && sessionId != null) {
          if (processedSessionIds.contains(sessionId)) {
            // شريك تم دمجه بالفعل، تخطاه لمنع التكرار!
            continue;
          }
          // أول شريك نلقاه: نقوم بتحديث اسمه ليصبح مدمجاً
          processedSessionIds.add(sessionId);

          // البحث عن اسم وصورة الشريك الحقيقيين ديناميكياً من القائمة
          final partnerUid = u['cooperativePartnerUid'] as String?;
          String partnerName = u['cooperativePartnerName'] as String? ?? 'شريك التحدي';
          partnerName = _cleanName(partnerName);
          int partnerAvIdx = (u['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;
          
          if (partnerUid != null) {
            final partnerDoc = users.firstWhere(
              (otherUser) => otherUser['id'] == partnerUid,
              orElse: () => <String, dynamic>{},
            );
            if (partnerDoc.isNotEmpty) {
              final partnerProfile = partnerDoc['user_profile_v1'] as Map<String, dynamic>? ?? {};
              final realName = partnerProfile['fullName'] as String?;
              final realAvatar = partnerDoc['avatarIndex'] as int?;
              if (realName != null && realName.isNotEmpty) {
                partnerName = _cleanName(realName);
              }
              if (realAvatar != null) {
                partnerAvIdx = realAvatar;
              }
            }
          }

          final myName = _cleanName(profile['fullName'] as String? ?? 'مستخدم');
          
          // تحديث الاسم والمعلومات المعروضة محلياً في القائمة
          profile['fullName'] = '$myName 🤝 $partnerName';
          u['user_profile_v1'] = profile;
          u['cooperativePartnerName'] = partnerName;
          u['cooperativePartnerAvatarIndex'] = partnerAvIdx;
          mergedUsers.add(u);
        } else {
          mergedUsers.add(u);
        }
      }
      users = mergedUsers;

      // ── إيجاد المستخدم الحالي (أو شريكه لتمييز الصف المدمج كـ "أنا") ──────────────
      final myIdx = users.indexWhere((u) {
        final p = u['user_profile_v1'] as Map<String, dynamic>? ?? {};
        final isCooperative = p['challengeType'] == 'تعاوني';
        return u['id'] == widget.uid || (isCooperative && u['cooperativePartnerUid'] == widget.uid);
      });
      Map<String, dynamic>? myData = myIdx >= 0 ? users[myIdx] : null;

      // إذا لم يكن ضمن الـ top 100 في هذا التبويب، نجلب بياناته منفردة للشريط السفلي
      if (myData == null && widget.uid.isNotEmpty) {
        final doc = await col.doc(widget.uid).get();
        if (doc.exists) { 
          final map = {'id': doc.id, ...doc.data()!};
          // إذا كان في تحدي تعاوني، ندمج اسم الشريك في الشريط السفلي أيضاً
          final profile = map['user_profile_v1'] as Map<String, dynamic>? ?? {};
          final isCoop = profile['challengeType'] == 'تعاوني';
          if (isCoop) {
            final partnerUid = map['cooperativePartnerUid'] as String?;
            String partnerName = map['cooperativePartnerName'] as String? ?? 'شريك التحدي';
            partnerName = _cleanName(partnerName);
            int partnerAvIdx = (map['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;
            
            if (partnerUid != null) {
              final partnerDoc = users.firstWhere(
                (otherUser) => otherUser['id'] == partnerUid,
                orElse: () => <String, dynamic>{},
              );
              if (partnerDoc.isNotEmpty) {
                final partnerProfile = partnerDoc['user_profile_v1'] as Map<String, dynamic>? ?? {};
                final realName = partnerProfile['fullName'] as String?;
                final realAvatar = partnerDoc['avatarIndex'] as int?;
                if (realName != null && realName.isNotEmpty) {
                  partnerName = _cleanName(realName);
                }
                if (realAvatar != null) {
                  partnerAvIdx = realAvatar;
                }
              }
            }

            final myName = _cleanName(profile['fullName'] as String? ?? 'مستخدم');
            profile['fullName'] = '$myName 🤝 $partnerName';
            map['user_profile_v1'] = profile;
            map['cooperativePartnerName'] = partnerName;
            map['cooperativePartnerAvatarIndex'] = partnerAvIdx;
          }
          myData = map;
        }
      }

      if (mounted) {
        setState(() {
          _users  = users;
          _myRank = myIdx >= 0 ? myIdx + 1 : -1;
          _myData = myData;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Firebase Error: ${e.toString()}');
      if (mounted) { setState(() { _loading = false; _error = e.toString(); }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.charcoal));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('تعذّر تحميل البيانات',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text(_error!.contains('index') || _error!.contains('Index')
                ? 'قد يحتاج الأمر لإعداد فهرس Firestore'
                : '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.mode == _Mode.club ? Icons.lock_rounded : Icons.people_outline_rounded,
            size: 48, color: AppColors.borderLight),
        const SizedBox(height: 12),
        Text(widget.mode == _Mode.club
            ? 'لا أحد أكمل التحدي بعد\nكن أول الأبطال! 🏆'
            : 'لا يوجد بيانات بعد',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
      ]),
    );
    }

    final amIComplete = _myData != null && _isComplete(_myData!);
    final showLock  = widget.mode == _Mode.club && !amIComplete;
    final inTop3    = _myRank >= 1 && _myRank <= 3;
    final showBar   = !inTop3 && _myData != null && !showLock;

    return Stack(children: [
      RefreshIndicator(
        color: AppColors.charcoal,
        onRefresh: _fetch,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, showBar ? 100 : 24),
          itemCount: _users.length + (showLock ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (showLock && i == 0) return const _LockBanner();
            final idx = showLock ? i - 1 : i;
            if (idx < 0 || idx >= _users.length) return const SizedBox.shrink();
            final userDoc = _users[idx];
            final p = userDoc['user_profile_v1'] as Map<String, dynamic>? ?? {};
            final isCooperative = p['challengeType'] == 'تعاوني';
            return _LeaderItem(
              rank: idx + 1,
              user: userDoc,
              mode: widget.mode,
              isMe: userDoc['id'] == widget.uid || (isCooperative && userDoc['cooperativePartnerUid'] == widget.uid),
              days: _days(userDoc),
              myUid: widget.uid,
            );
          },
        ),
      ),
      if (showBar)
        Positioned(bottom: 0, left: 0, right: 0,
          child: _MyBar(
            rank: _myRank > 0 ? _myRank : _users.length + 1,
            user: _myData!,
            mode: widget.mode,
            days: _myData != null ? _days(_myData!) : 0,
          ),
        ),
    ]);
  }
}

// ─── Lock Banner ──────────────────────────────────────────────────────────────
class _LockBanner extends StatelessWidget {
  const _LockBanner();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.cardFill, AppColors.borderLight.withValues(alpha: 0.3)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: _r3Grad),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 14),
      const Text('هنا يخلد الأبطال..', textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.charcoal)),
      const SizedBox(height: 8),
      const Text('أكمل تحديك لينضم اسمك لقاعة المشاهير',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
    ]),
  );
}

// ─── Leader Item ──────────────────────────────────────────────────────────────
class _LeaderItem extends StatelessWidget {
  final int rank, days;
  final Map<String, dynamic> user;
  final _Mode mode;
  final bool isMe;
  final String myUid;
  const _LeaderItem({
    required this.rank,
    required this.user,
    required this.mode,
    required this.isMe,
    required this.days,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final avIdx = user['avatarIndex'] as int? ?? 0;
    final isTop = rank <= 3;
    final bool isCoop = profile['challengeType'] == 'تعاوني';
    final int partnerAvIdx = (user['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;

    String displayName = profile['fullName'] as String? ?? 'مستخدم';
    int displayAvIdx = avIdx;
    int displayPartnerAvIdx = partnerAvIdx;

    if (isCoop && myUid.isNotEmpty) {
      final partnerUid = user['cooperativePartnerUid'] as String?;
      if (myUid == partnerUid) {
        // Swap names so the logged-in partner sees their own name first
        final rawName = profile['fullName'] as String? ?? 'مستخدم';
        if (rawName.contains(' 🤝 ')) {
          final parts = rawName.split(' 🤝 ');
          if (parts.length == 2) {
            displayName = '${parts[1]} 🤝 ${parts[0]}';
          }
        }

        // Swap avatars so the logged-in partner's avatar is on top
        displayAvIdx = partnerAvIdx;
        displayPartnerAvIdx = avIdx;
      }
    }

    final String sub;
    switch (mode) {
      case _Mode.streak:
        final s = user['current_streak_v1'] as int? ?? 0;
        sub = '$s يوم التزام';
      case _Mode.road:
        sub = '$days / 100 يوم مكتمل';
      case _Mode.club:
        final ts = user['completedAt'];
        sub = ts is Timestamp
            ? 'أكمل في ${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
            : 'بطل المئة 🏆';
    }

    final Widget rankW = isTop
        ? Text(rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
            style: const TextStyle(fontSize: 22))
        : Text('#$rank',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                color: AppColors.textSecondary));

    final String scoreLabel;
    switch (mode) {
      case _Mode.streak: scoreLabel = '${user['current_streak_v1'] as int? ?? 0}🔥';
      case _Mode.road:   scoreLabel = '$days📅';
      case _Mode.club:   scoreLabel = '✅';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.charcoal.withValues(alpha: 0.05) : AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.charcoal.withValues(alpha: 0.4) : AppColors.borderLight,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: isTop ? [
          BoxShadow(color: _rankBorder(rank).withValues(alpha: 0.15),
              blurRadius: 12, offset: const Offset(0, 3))
        ] : null,
      ),
      child: Row(children: [
        // Rank number — يمين
        SizedBox(width: isTop ? 42 : 46, child: Center(child: rankW)),
        // Avatar
        Container(
          decoration: (isTop && !isCoop) ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _rankBorder(rank), width: 2.5),
            boxShadow: [BoxShadow(color: _rankBorder(rank).withValues(alpha: 0.35), blurRadius: 8)],
          ) : null,
          child: isCoop
              ? LinkedAvatars(
                  userAvatarIndex: displayAvIdx,
                  partnerAvatarIndex: displayPartnerAvIdx,
                  size: 46,
                  overlapMultiplier: 0.4,
                )
              : ClipOval(child: FacelessAvatar(index: displayAvIdx, size: 46)),
        ),
        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(displayName, textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: isTop ? FontWeight.w800 : FontWeight.w700,
                      fontSize: isTop ? 15 : 14,
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (isCoop && !displayName.contains('🤝')) ...[
                  const SizedBox(width: 4),
                  const Text('🤝', style: TextStyle(fontSize: 14)),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(sub, textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
        const SizedBox(width: 10),
        // Score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isTop
                ? _rankBorder(rank).withValues(alpha: 0.12)
                : AppColors.borderLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(scoreLabel,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isTop ? _rankBorder(rank) : AppColors.textSecondary,
            )),
        ),
        if (isTop) ...[
          const SizedBox(width: 12),
          Container(
            width: 5, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _rankGrad(rank), begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
          ),
        ] else
          const SizedBox(width: 12),
      ]),
    );
  }
}

// ─── Sticky My-Position Bar ───────────────────────────────────────────────────
class _MyBar extends StatelessWidget {
  final int rank, days;
  final Map<String, dynamic> user;
  final _Mode mode;
  const _MyBar({required this.rank, required this.user, required this.mode, required this.days});

  @override
  Widget build(BuildContext context) {
    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final bool isCoop = profile['challengeType'] == 'تعاوني';
    final avIdx = user['avatarIndex'] as int? ?? 0;
    final int partnerAvIdx = (user['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;

    String displayName = isCoop ? (profile['fullName'] as String? ?? 'أنت') : (profile['fullName'] as String? ?? 'أنت').split(' ').first;
    int displayAvIdx = avIdx;
    int displayPartnerAvIdx = partnerAvIdx;

    if (isCoop) {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final partnerUid = user['cooperativePartnerUid'] as String?;
      if (myUid.isNotEmpty && myUid == partnerUid) {
        // Swap names so the logged-in partner sees their own name first
        final rawName = profile['fullName'] as String? ?? 'مستخدم';
        if (rawName.contains(' 🤝 ')) {
          final parts = rawName.split(' 🤝 ');
          if (parts.length == 2) {
            displayName = '${parts[1]} 🤝 ${parts[0]}';
          }
        }
        // Swap avatars so the logged-in partner's avatar is on top
        displayAvIdx = partnerAvIdx;
        displayPartnerAvIdx = avIdx;
      }
    }

    final String tip;
    switch (mode) {
      case _Mode.streak: tip = 'حافظ على الإيداع اليومي لترتفع في الترتيب!';
      case _Mode.road:   tip = 'يومٌ آخر يقربك من القمة — استمر!';
      case _Mode.club:   tip = 'أكمل تحديك لتدخل قاعة المشاهير!';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1A0E), Color(0xFF4A3020)],
            begin: Alignment.centerRight, end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 5),
          )],
        ),
        child: Row(children: [
          // الاسم والنصيحة — يمين
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(tip, textAlign: TextAlign.start,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, height: 1.3)),
            ],
          )),
          const SizedBox(width: 12),
          isCoop
              ? LinkedAvatars(
                  userAvatarIndex: displayAvIdx,
                  partnerAvatarIndex: displayPartnerAvIdx,
                  size: 42,
                  overlapMultiplier: 0.4,
                )
              : ClipOval(child: FacelessAvatar(index: displayAvIdx, size: 42)),
          const SizedBox(width: 12),
          // الترتيب — يسار
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rank == -1 ? '100+' : '#$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
        ]),
      ),
    );
  }
}
