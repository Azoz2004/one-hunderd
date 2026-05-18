import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
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
              indicator: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.charcoal, Color(0xFF4A3828)]),
                borderRadius: BorderRadius.circular(10),
              ),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
              padding: const EdgeInsets.all(3),
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

  int _days(Map<String, dynamic> u) =>
      (u['deposits_v1'] as List? ?? []).length;

  bool _isComplete(Map<String, dynamic> u) =>
      (u['is_complete_v1'] as bool? ?? false) || _days(u) >= 100;

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      // Fetch all users client-side — avoids Firestore composite index requirements
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final all = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      List<Map<String, dynamic>> users;
      switch (widget.mode) {
        case _Mode.streak:
          users = List.from(all)..sort((a, b) {
            final sa = a['current_streak_v1'] as int? ?? 0;
            final sb = b['current_streak_v1'] as int? ?? 0;
            return sb.compareTo(sa);
          });
        case _Mode.road:
          users = all.where((u) => !_isComplete(u)).toList()
            ..sort((a, b) => _days(b).compareTo(_days(a)));
        case _Mode.club:
          users = all.where(_isComplete).toList()..sort((a, b) {
            final ta = a['completedAt'];
            final tb = b['completedAt'];
            if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
            if (ta is Timestamp) return -1;
            if (tb is Timestamp) return 1;
            return 0;
          });
      }
      if (users.length > 100) users = users.sublist(0, 100);

      final myIdx = users.indexWhere((u) => u['id'] == widget.uid);
      Map<String, dynamic>? myData = myIdx >= 0 ? users[myIdx] : null;
      if (myData == null && widget.uid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(widget.uid).get();
        if (doc.exists) { myData = {'id': doc.id, ...doc.data()!}; }
      }

      if (mounted) setState(() {
        _users  = users;
        _myRank = myIdx >= 0 ? myIdx + 1 : -1;
        _myData = myData;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.charcoal));
    if (_error != null) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('تعذّر تحميل البيانات', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextButton(onPressed: _fetch, child: const Text('إعادة المحاولة')),
      ]),
    );
    if (_users.isEmpty) return const Center(
      child: Text('لا يوجد بيانات بعد', style: TextStyle(color: AppColors.textSecondary)),
    );

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
            return _LeaderItem(
              rank: idx + 1,
              user: _users[idx],
              mode: widget.mode,
              isMe: _users[idx]['id'] == widget.uid,
              days: _days(_users[idx]),
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
  const _LeaderItem({required this.rank, required this.user, required this.mode,
      required this.isMe, required this.days});

  @override
  Widget build(BuildContext context) {
    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final name  = profile['fullName'] as String? ?? 'مستخدم';
    final avIdx = user['avatarIndex'] as int? ?? 0;
    final isTop = rank <= 3;

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
        // Left accent bar for top 3
        if (isTop)
          Container(
            width: 5, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _rankGrad(rank), begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
          ),
        // Rank number
        SizedBox(width: isTop ? 42 : 46, child: Center(child: rankW)),
        // Avatar
        Container(
          decoration: isTop ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _rankBorder(rank), width: 2.5),
            boxShadow: [BoxShadow(color: _rankBorder(rank).withValues(alpha: 0.35), blurRadius: 8)],
          ) : null,
          child: ClipOval(child: FacelessAvatar(index: avIdx, size: 46)),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(name, textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isTop ? FontWeight.w800 : FontWeight.w700,
                fontSize: isTop ? 15 : 14,
                color: AppColors.charcoal,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(sub, textAlign: TextAlign.right,
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
    final name  = (profile['fullName'] as String? ?? 'أنت').split(' ').first;
    final avIdx = user['avatarIndex'] as int? ?? 0;

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
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 5),
          )],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('#$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          ),
          const SizedBox(width: 12),
          ClipOval(child: FacelessAvatar(index: avIdx, size: 42)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(tip, textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, height: 1.3)),
            ],
          )),
        ]),
      ),
    );
  }
}
