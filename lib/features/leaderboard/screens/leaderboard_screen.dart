import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart';
import 'package:one_hunderd/features/profile/screens/user_profile_detail_screen.dart';

enum _Mode { streak, road, club }

// ─── Rank Colours ──────────────────────────────────────────────────────────────
const _gold   = Color(0xFFE8B84B);
const _silver = Color(0xFF9BA8B0);
const _bronze = Color(0xFFC0845A);

Color _medalColor(int r) => r == 1 ? _gold : r == 2 ? _silver : _bronze;
Color _medalBg(int r) => r == 1
    ? const Color(0xFFFFF8E8)
    : r == 2
        ? const Color(0xFFF4F5F6)
        : const Color(0xFFFAF0E8);

// ══════════════════════════════════════════════════════════════════════════════
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 64,
              leading: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.charcoal),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: _gold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'لوحة الصدارة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: TabBar(
                      controller: _tc,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      indicator: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.charcoal.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      tabs: const [
                        Tab(
                          height: 38,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department_rounded, size: 16),
                              SizedBox(width: 5),
                              Text('الالتزام'),
                            ],
                          ),
                        ),
                        Tab(
                          height: 38,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_run_rounded, size: 16),
                              SizedBox(width: 5),
                              Text('الساعون للمئة'),
                            ],
                          ),
                        ),
                        Tab(
                          height: 38,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 16),
                              SizedBox(width: 5),
                              Text('نادي المئة'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tc,
            children: [
              _LeaderTab(mode: _Mode.streak, uid: _uid),
              _LeaderTab(mode: _Mode.road,   uid: _uid),
              _LeaderTab(mode: _Mode.club,   uid: _uid),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
class _LeaderTab extends StatefulWidget {
  final _Mode mode;
  final String uid;
  const _LeaderTab({required this.mode, required this.uid});
  @override
  State<_LeaderTab> createState() => _LeaderTabState();
}

class _LeaderTabState extends State<_LeaderTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int  _myRank = -1;
  Map<String, dynamic>? _myData;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _cleanName(String name) {
    if (name.contains(' 🤝 ')) return name.split(' 🤝 ').first.trim();
    return name.trim();
  }

  int _days(Map<String, dynamic> u) {
    final cached = u['completed_days_count'] as int?;
    if (cached != null) return cached;
    return (u['deposits_v1'] as List? ?? []).length;
  }

  bool _isComplete(Map<String, dynamic> u) =>
      (u['is_complete_v1'] as bool? ?? false) || _days(u) >= 100;

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      List<Map<String, dynamic>> users;
      final col = FirebaseFirestore.instance.collection('users');

      switch (widget.mode) {
        case _Mode.streak:
          final snap = await col
              .orderBy('current_streak_v1', descending: true)
              .limit(100)
              .get();
          users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

        case _Mode.road:
          final snap = await col
              .where('is_complete_v1', isEqualTo: false)
              .orderBy('completed_days_count', descending: true)
              .limit(100)
              .get();
          final snapFallback = await col
              .where('is_complete_v1', isNull: true)
              .orderBy('completed_days_count', descending: true)
              .limit(50)
              .get();
          final allDocs = {
            ...{for (final d in snap.docs) d.id: d},
            ...{for (final d in snapFallback.docs) d.id: d},
          };
          users = allDocs.values.map((d) => {'id': d.id, ...d.data()}).toList();
          users = users.where((u) => !_isComplete(u)).toList();
          users.sort((a, b) => _days(b).compareTo(_days(a)));
          if (users.length > 100) users = users.sublist(0, 100);

        case _Mode.club:
          final snap = await col
              .where('is_complete_v1', isEqualTo: true)
              .orderBy('completedAt')
              .limit(100)
              .get();
          users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      // Merge cooperative partners
      final List<Map<String, dynamic>> mergedUsers = [];
      final Set<String> processedSessionIds = {};

      for (var u in users) {
        final profile = u['user_profile_v1'] as Map<String, dynamic>? ?? {};
        final isCoop = profile['challengeType'] == 'تعاوني';
        final sessionId = u['activeSessionId'] as String?;

        if (isCoop && sessionId != null) {
          if (processedSessionIds.contains(sessionId)) continue;
          processedSessionIds.add(sessionId);

          final partnerUid = u['cooperativePartnerUid'] as String?;
          String partnerName = u['cooperativePartnerName'] as String? ?? 'شريك التحدي';
          partnerName = _cleanName(partnerName);
          int partnerAvIdx = (u['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;

          if (partnerUid != null) {
            final partnerDoc = users.firstWhere(
              (o) => o['id'] == partnerUid,
              orElse: () => <String, dynamic>{},
            );
            if (partnerDoc.isNotEmpty) {
              final pp = partnerDoc['user_profile_v1'] as Map<String, dynamic>? ?? {};
              final realName   = pp['fullName'] as String?;
              final realAvatar = partnerDoc['avatarIndex'] as int?;
              if (realName != null && realName.isNotEmpty) partnerName = _cleanName(realName);
              if (realAvatar != null) partnerAvIdx = realAvatar;
            }
          }

          final myName = _cleanName(profile['fullName'] as String? ?? 'مستخدم');
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

      final myIdx = users.indexWhere((u) {
        final p = u['user_profile_v1'] as Map<String, dynamic>? ?? {};
        final isCooperative = p['challengeType'] == 'تعاوني';
        return u['id'] == widget.uid ||
            (isCooperative && u['cooperativePartnerUid'] == widget.uid);
      });
      Map<String, dynamic>? myData = myIdx >= 0 ? users[myIdx] : null;

      if (myData == null && widget.uid.isNotEmpty) {
        final doc = await col.doc(widget.uid).get();
        if (doc.exists) {
          final map = {'id': doc.id, ...doc.data()!};
          final profile = map['user_profile_v1'] as Map<String, dynamic>? ?? {};
          final isCoop = profile['challengeType'] == 'تعاوني';
          if (isCoop) {
            final partnerUid = map['cooperativePartnerUid'] as String?;
            String partnerName = map['cooperativePartnerName'] as String? ?? 'شريك التحدي';
            partnerName = _cleanName(partnerName);
            int partnerAvIdx = (map['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;
            if (partnerUid != null) {
              final partnerDoc = users.firstWhere(
                (o) => o['id'] == partnerUid,
                orElse: () => <String, dynamic>{},
              );
              if (partnerDoc.isNotEmpty) {
                final pp = partnerDoc['user_profile_v1'] as Map<String, dynamic>? ?? {};
                final realName   = pp['fullName'] as String?;
                final realAvatar = partnerDoc['avatarIndex'] as int?;
                if (realName != null && realName.isNotEmpty) partnerName = _cleanName(realName);
                if (realAvatar != null) partnerAvIdx = realAvatar;
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
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.charcoal,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.cardFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 28, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('تعذّر تحميل البيانات',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                )),
              const SizedBox(height: 6),
              const Text('تحقق من اتصالك بالإنترنت',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                )),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.charcoal),
                label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.charcoal, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.mode == _Mode.club
                    ? Icons.workspace_premium_rounded
                    : Icons.group_outlined,
                size: 56,
                color: AppColors.borderLight,
              ),
              const SizedBox(height: 16),
              Text(
                widget.mode == _Mode.club
                    ? 'لا أحد أكمل التحدي بعد\nكن أول الأبطال! 🏆'
                    : 'لا يوجد بيانات بعد',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final amIComplete = _myData != null && _isComplete(_myData!);
    final showLock = widget.mode == _Mode.club && !amIComplete;
    final inTop3   = _myRank >= 1 && _myRank <= 3;
    final showBar  = !inTop3 && _myData != null && !showLock;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.charcoal,
          onRefresh: _fetch,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, showBar ? 100 : 24),
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
                isMe: userDoc['id'] == widget.uid ||
                    (isCooperative && userDoc['cooperativePartnerUid'] == widget.uid),
                days: _days(userDoc),
                myUid: widget.uid,
                animIndex: i,
              );
            },
          ),
        ),
        if (showBar)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _MyBar(
              rank: _myRank > 0 ? _myRank : _users.length + 1,
              user: _myData!,
              mode: widget.mode,
              days: _myData != null ? _days(_myData!) : 0,
            ),
          ),
      ],
    );
  }
}

// ─── Lock Banner ───────────────────────────────────────────────────────────────
class _LockBanner extends StatelessWidget {
  const _LockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.lock_rounded, color: _gold, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'هنا يخلد الأبطال..',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أكمل تحديك لينضم اسمك لقاعة المشاهير',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leader Item ───────────────────────────────────────────────────────────────
class _LeaderItem extends StatelessWidget {
  final int rank, days, animIndex;
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
    required this.animIndex,
  });

  /// Returns first word of a name only
  String _firstName(String name) => name.trim().split(' ').first;

  /// Builds a clean display name: first-name only for solo, "name1 & name2" for coop (no emoji)
  String _buildDisplayName(String rawCombined, bool isCoop) {
    if (!isCoop) return _firstName(rawCombined);
    if (rawCombined.contains(' 🤝 ')) {
      final parts = rawCombined.split(' 🤝 ');
      if (parts.length == 2) {
        return '${_firstName(parts[0])} & ${_firstName(parts[1])}';
      }
    }
    return _firstName(rawCombined);
  }

  void _handleTap(BuildContext context) {
    // If tapping own entry, open own editable profile screen
    if (isMe) {
      Navigator.push(
        context,
        AppScalePageRoute(page: const ProfileScreen()),
      );
      return;
    }

    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final bool isCoop = profile['challengeType'] == 'تعاوني';
    final partnerUid = user['cooperativePartnerUid'] as String?;

    if (isCoop && partnerUid != null && partnerUid.isNotEmpty) {
      final rawName = profile['fullName'] as String? ?? 'مستخدم';
      final parts = rawName.split(' 🤝 ');
      final nameA = parts.isNotEmpty ? _firstName(parts[0]) : 'مستخدم';
      final nameB = parts.length > 1
          ? _firstName(parts[1])
          : _firstName(user['cooperativePartnerName'] as String? ?? 'الشريك');

      final uidA = user['id'] as String;
      final avA  = user['avatarIndex'] as int? ?? 0;
      final uidB = partnerUid;
      final avB  = (user['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;

      _showCooperativePartnerDialog(
        context,
        uidA: uidA,
        nameA: nameA,
        avatarA: avA,
        uidB: uidB,
        nameB: nameB,
        avatarB: avB,
      );
    } else {
      final uid = user['id'] as String;
      final rawName = profile['fullName'] as String? ?? 'مستخدم';
      final name = _firstName(rawName.split(' 🤝 ').first);
      final av = user['avatarIndex'] as int? ?? 0;

      Navigator.push(
        context,
        AppScalePageRoute(
          page: UserProfileDetailScreen(
            userId: uid,
            initialName: name,
            initialAvatarIndex: av,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final avIdx   = user['avatarIndex'] as int? ?? 0;
    final bool isCoop = profile['challengeType'] == 'تعاوني';
    final int partnerAvIdx = (user['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;
    final isTop = rank <= 3;

    String rawName = profile['fullName'] as String? ?? 'مستخدم';
    int displayAvIdx        = avIdx;
    int displayPartnerAvIdx = partnerAvIdx;

    if (isCoop && myUid.isNotEmpty) {
      final partnerUid = user['cooperativePartnerUid'] as String?;
      if (myUid == partnerUid) {
        // Swap so logged-in user's name appears first
        if (rawName.contains(' 🤝 ')) {
          final parts = rawName.split(' 🤝 ');
          if (parts.length == 2) rawName = '${parts[1]} 🤝 ${parts[0]}';
        }
        displayAvIdx        = partnerAvIdx;
        displayPartnerAvIdx = avIdx;
      }
    }

    final String displayName = _buildDisplayName(rawName, isCoop);

    // ── Score values ──
    final String scoreValue;
    final String scoreUnit;
    final Color scoreColor;
    final IconData scoreIcon;

    switch (mode) {
      case _Mode.streak:
        final s = user['current_streak_v1'] as int? ?? 0;
        scoreValue = '$s';
        scoreUnit  = ''; // Removed "يوم"
        scoreColor = const Color(0xFFE65C00);
        scoreIcon  = Icons.local_fire_department_rounded;
      case _Mode.road:
        scoreValue = '$days';
        scoreUnit  = '/ 100';
        scoreColor = AppColors.charcoal;
        scoreIcon  = Icons.calendar_today_rounded;
      case _Mode.club:
        final ts = user['completedAt'];
        if (ts is Timestamp) {
          final d = ts.toDate();
          scoreValue = '${d.day}/${d.month}/${d.year}';
          scoreUnit  = '';
        } else {
          scoreValue = 'مكتمل';
          scoreUnit  = '';
        }
        scoreColor = const Color(0xFF2E7D32);
        scoreIcon  = Icons.workspace_premium_rounded;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('item-$rank'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + animIndex * 40),
      curve: Curves.easeOutCubic,
      builder: (ctx, value, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: isTop
          ? _TopCard(
              rank: rank,
              displayName: displayName,
              displayAvIdx: displayAvIdx,
              displayPartnerAvIdx: displayPartnerAvIdx,
              isCoop: isCoop,
              isMe: isMe,
              scoreValue: scoreValue,
              scoreUnit: scoreUnit,
              scoreColor: scoreColor,
              scoreIcon: scoreIcon,
              mode: mode,
              onTap: () => _handleTap(context),
            )
          : _RegularRow(
              rank: rank,
              displayName: displayName,
              displayAvIdx: displayAvIdx,
              displayPartnerAvIdx: displayPartnerAvIdx,
              isCoop: isCoop,
              isMe: isMe,
              scoreValue: scoreValue,
              scoreUnit: scoreUnit,
              scoreColor: scoreColor,
              scoreIcon: scoreIcon,
              onTap: () => _handleTap(context),
            ),
    );
  }
}

// ── Top 3 Card ─────────────────────────────────────────────────────────────────
class _TopCard extends StatelessWidget {
  final int rank;
  final String displayName, scoreValue, scoreUnit;
  final int displayAvIdx, displayPartnerAvIdx;
  final bool isCoop, isMe;
  final Color scoreColor;
  final IconData scoreIcon;
  final _Mode mode;
  final VoidCallback onTap;

  const _TopCard({
    required this.rank,
    required this.displayName,
    required this.displayAvIdx,
    required this.displayPartnerAvIdx,
    required this.isCoop,
    required this.isMe,
    required this.scoreValue,
    required this.scoreUnit,
    required this.scoreColor,
    required this.scoreIcon,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mc = _medalColor(rank);
    final mb = _medalBg(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.charcoal.withValues(alpha: 0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? AppColors.charcoal.withValues(alpha: 0.35) : mc.withValues(alpha: 0.25),
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: mc.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ── Medal badge ──
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: mb,
                    shape: BoxShape.circle,
                    border: Border.all(color: mc.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Avatar ──
                isCoop
                    ? LinkedAvatars(
                        userAvatarIndex: displayAvIdx,
                        partnerAvatarIndex: displayPartnerAvIdx,
                        size: 48,
                        overlapMultiplier: 0.4,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: mc, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: mc.withValues(alpha: 0.30),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(child: FacelessAvatar(index: displayAvIdx, size: 48)),
                      ),
                const SizedBox(width: 10),

                // ── Name (gets max space) ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'أنت',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // ── Score Badge ──
                _ScoreBadge(
                  value: scoreValue,
                  unit: scoreUnit,
                  color: scoreColor,
                  icon: scoreIcon,
                  large: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Regular Row (rank 4+) ──────────────────────────────────────────────────────
class _RegularRow extends StatelessWidget {
  final int rank;
  final String displayName, scoreValue, scoreUnit;
  final int displayAvIdx, displayPartnerAvIdx;
  final bool isCoop, isMe;
  final Color scoreColor;
  final IconData scoreIcon;
  final VoidCallback onTap;

  const _RegularRow({
    required this.rank,
    required this.displayName,
    required this.displayAvIdx,
    required this.displayPartnerAvIdx,
    required this.isCoop,
    required this.isMe,
    required this.scoreValue,
    required this.scoreUnit,
    required this.scoreColor,
    required this.scoreIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? AppColors.charcoal.withValues(alpha: 0.04) : AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.charcoal.withValues(alpha: 0.30)
              : AppColors.border.withValues(alpha: 0.5),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // ── Rank ──
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isMe ? AppColors.charcoal : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // ── Avatar ──
                isCoop
                    ? LinkedAvatars(
                        userAvatarIndex: displayAvIdx,
                        partnerAvatarIndex: displayPartnerAvIdx,
                        size: 40,
                        overlapMultiplier: 0.4,
                      )
                    : ClipOval(child: FacelessAvatar(index: displayAvIdx, size: 40)),
                const SizedBox(width: 10),

                // ── Name (gets max space) ──
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'أنت',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // ── Score ──
                _ScoreBadge(
                  value: scoreValue,
                  unit: scoreUnit,
                  color: scoreColor,
                  icon: scoreIcon,
                  large: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score Badge ────────────────────────────────────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final String value, unit;
  final Color color;
  final IconData icon;
  final bool large;

  const _ScoreBadge({
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final isStreak = icon == Icons.local_fire_department_rounded;
    final isDate = value.contains('/');
    final double iconSize = isStreak ? (large ? 18.0 : 16.0) : (large ? 14.0 : 12.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 7,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            textDirection: isDate ? TextDirection.ltr : null,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: large ? (isDate ? 13 : 15) : (isDate ? 11 : 13),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: large ? 11 : 10,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── My Position Sticky Bar ────────────────────────────────────────────────────
class _MyBar extends StatelessWidget {
  final int rank, days;
  final Map<String, dynamic> user;
  final _Mode mode;

  const _MyBar({
    required this.rank,
    required this.user,
    required this.mode,
    required this.days,
  });


  void _handleTap(BuildContext context) {
    Navigator.push(
      context,
      AppScalePageRoute(page: const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = user['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final bool isCoop = profile['challengeType'] == 'تعاوني';
    final avIdx = user['avatarIndex'] as int? ?? 0;
    final int partnerAvIdx = (user['cooperativePartnerAvatarIndex'] as num?)?.toInt() ?? 0;

    String rawName = profile['fullName'] as String? ?? 'أنت';
    int displayAvIdx        = avIdx;
    int displayPartnerAvIdx = partnerAvIdx;

    if (isCoop) {
      final myUid    = FirebaseAuth.instance.currentUser?.uid ?? '';
      final partnerUid = user['cooperativePartnerUid'] as String?;
      if (myUid.isNotEmpty && myUid == partnerUid) {
        if (rawName.contains(' 🤝 ')) {
          final parts = rawName.split(' 🤝 ');
          if (parts.length == 2) rawName = '${parts[1]} 🤝 ${parts[0]}';
        }
        displayAvIdx        = partnerAvIdx;
        displayPartnerAvIdx = avIdx;
      }
    }

    final String displayName;
    if (isCoop && rawName.contains(' 🤝 ')) {
      final parts = rawName.split(' 🤝 ');
      if (parts.length == 2) {
        displayName = '${parts[0].trim().split(' ').first} & ${parts[1].trim().split(' ').first}';
      } else {
        displayName = rawName.trim().split(' ').first;
      }
    } else {
      displayName = rawName.trim().split(' ').first;
    }

    final String scoreValue;
    final String scoreUnit;
    final Color scoreColor;
    final IconData scoreIcon;

    switch (mode) {
      case _Mode.streak:
        final s = user['current_streak_v1'] as int? ?? 0;
        scoreValue = '$s';
        scoreUnit  = '';
        scoreColor = const Color(0xFFFF8C42);
        scoreIcon  = Icons.local_fire_department_rounded;
      case _Mode.road:
        scoreValue = '$days';
        scoreUnit  = '/ 100';
        scoreColor = Colors.white;
        scoreIcon  = Icons.calendar_today_rounded;
      case _Mode.club:
        scoreValue = 'مكتمل';
        scoreUnit  = '';
        scoreColor = const Color(0xFF81C784);
        scoreIcon  = Icons.workspace_premium_rounded;
    }

    final rankDisplay = rank == -1 ? '100+' : '#$rank';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _handleTap(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // ── Avatar ──
                  isCoop
                      ? LinkedAvatars(
                          userAvatarIndex: displayAvIdx,
                          partnerAvatarIndex: displayPartnerAvIdx,
                          size: 44,
                          overlapMultiplier: 0.4,
                        )
                      : ClipOval(child: FacelessAvatar(index: displayAvIdx, size: 44)),
                  const SizedBox(width: 12),

                  // ── Name ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مركزك في الترتيب',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Score ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(scoreIcon, size: 15, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          scoreValue,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: scoreColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (scoreUnit.isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Text(
                            scoreUnit,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Rank ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      rankDisplay,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog for choosing which cooperative partner profile to view
// ══════════════════════════════════════════════════════════════════════════════
void _showCooperativePartnerDialog(
  BuildContext context, {
  required String uidA,
  required String nameA,
  required int avatarA,
  required String uidB,
  required String nameB,
  required int avatarB,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: const Column(
                children: [
                  Text(
                    'اختر الملف الشخصي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'انقر على أحد شريكي التحدي لزيارة ملفه',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PartnerChoiceCard(
                          uid: uidA,
                          name: nameA,
                          avatarIndex: avatarA,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              AppScalePageRoute(
                                page: UserProfileDetailScreen(
                                  userId: uidA,
                                  initialName: nameA,
                                  initialAvatarIndex: avatarA,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PartnerChoiceCard(
                          uid: uidB,
                          name: nameB,
                          avatarIndex: avatarB,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              AppScalePageRoute(
                                page: UserProfileDetailScreen(
                                  userId: uidB,
                                  initialName: nameB,
                                  initialAvatarIndex: avatarB,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PartnerChoiceCard extends StatefulWidget {
  final String uid;
  final String name;
  final int avatarIndex;
  final VoidCallback onTap;

  const _PartnerChoiceCard({
    required this.uid,
    required this.name,
    required this.avatarIndex,
    required this.onTap,
  });

  @override
  State<_PartnerChoiceCard> createState() => _PartnerChoiceCardState();
}

class _PartnerChoiceCardState extends State<_PartnerChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(child: FacelessAvatar(index: widget.avatarIndex, size: 54)),
              const SizedBox(height: 10),
              Text(
                widget.name.trim().split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'زيارة الملف',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
