import 'package:flutter/material.dart';
import 'package:one_hunderd/features/friends/services/friends_service.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/friends/screens/add_friend_screen.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart'; // FacelessAvatar
import 'package:one_hunderd/features/profile/screens/user_profile_detail_screen.dart';

/// صفحة قائمة الأصدقاء — مع تبويبين: أصدقائي / الطلبات
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  List<FriendUser> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await FriendsService.getFriends();
      final incoming = await FriendsService.getIncomingRequests();
      if (mounted) {
        setState(() {
          _friends = friends;
          _incoming = incoming;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _goToAddFriend() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    _load();
  }



  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'الأصدقاء',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: _goToAddFriend,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.person_rounded, size: 20, color: AppColors.charcoal),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.charcoal,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardFill, width: 1.5),
                          ),
                          child: const Icon(Icons.add_rounded, size: 9, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // ── التبويبين ──────────────────────────────────────────────────────
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                padding: EdgeInsets.zero,
                tabs: [
                  const Tab(text: 'أصدقائي'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('الطلبات'),
                        if (_incoming.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_incoming.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.charcoal),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'تعذّر تحميل البيانات',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tc,
      children: [
        // ── تبويب الأصدقاء ─────────────────────────────────────────────────
        RefreshIndicator(
          color: AppColors.charcoal,
          onRefresh: _load,
          child: _friends.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _EmptyFriends(onAddFriend: _goToAddFriend),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _friends.length,
                  itemBuilder: (ctx, i) {
                    final friend = _friends[i];
                    return GestureDetector(
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileDetailScreen(
                              userId: friend.uid,
                              initialName: friend.fullName,
                              initialAvatarIndex: friend.avatarIndex,
                              initialEmail: friend.email,
                            ),
                          ),
                        );
                        if (updated == true && mounted) {
                          _load();
                        }
                      },
                      child: _FriendCard(friend: friend),
                    );
                  },
                ),
        ),
        // ── تبويب الطلبات الواردة ──────────────────────────────────────────
        RefreshIndicator(
          color: AppColors.charcoal,
          onRefresh: _load,
          child: _incoming.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _EmptyRequests(),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _incoming.length,
                  itemBuilder: (ctx, i) {
                    final req = _incoming[i];
                    return _IncomingRequestCard(
                      request: req,
                      onAccept: () async {
                        try {
                          await FriendsService.acceptFriendRequest(
                            req['requestId'] as String,
                            (req['user'] as FriendUser).uid,
                          );
                          if (mounted) {
                            AppSnackbar.show(
                              context: context,
                              message: 'تم قبول طلب الصداقة بنجاح 🎉',
                              isSuccess: true,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackbar.show(
                              context: context,
                              message: 'تعذّر قبول الطلب: $e',
                              isSuccess: false,
                            );
                          }
                        }
                        _load();
                      },
                      onDecline: () async {
                        try {
                          await FriendsService.rejectFriendRequest(
                            req['requestId'] as String,
                          );
                          if (mounted) {
                            AppSnackbar.show(
                              context: context,
                              message: 'تم رفض طلب الصداقة 🚫',
                              isSuccess: false,
                              isDelete: true,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackbar.show(
                              context: context,
                              message: 'تعذّر رفض الطلب: $e',
                              isSuccess: false,
                            );
                          }
                        }
                        _load();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Empty State: لا أصدقاء ───────────────────────────────────────────────────
class _EmptyFriends extends StatelessWidget {
  final VoidCallback onAddFriend;
  const _EmptyFriends({required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 2),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا يوجد أصدقاء حتى الآن',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابحث عن أصدقائك وشاركهم رحلة التوفير!\nالتحدي مع صديق أمتع 💪',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddFriend,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('أضف أول صديق'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State: لا طلبات واردة ──────────────────────────────────────────────
class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 60,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد طلبات صداقة',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ستظهر هنا طلبات الصداقة الواردة إليك',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend Card ───────────────────────────────────────────────────────────────
class _FriendCard extends StatelessWidget {
  final FriendUser friend;
  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          ClipOval(child: FacelessAvatar(index: friend.avatarIndex, size: 52)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        friend.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 13, color: AppColors.green),
                const SizedBox(width: 4),
                Text(
                  'صديق',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
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

// ─── Incoming Request Card ─────────────────────────────────────────────────────
class _IncomingRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _IncomingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final user = request['user'] as FriendUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.charcoal.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          ClipOval(child: FacelessAvatar(index: user.avatarIndex, size: 46)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                const Text(
                  'يريد إضافتك كصديق',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Text(
                'رفض',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'قبول',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
