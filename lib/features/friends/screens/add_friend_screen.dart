import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/features/friends/services/friends_service.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/profile/screens/profile_screen.dart'; // FacelessAvatar
import 'package:one_hunderd/features/profile/screens/user_profile_detail_screen.dart';

/// شاشة إضافة صديق — ثلاثة خيارات
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

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
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'إضافة صديق',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              height: 42,
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
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                padding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: 'بحث بالاسم'),
                  Tab(text: 'بحث بالإيميل'),
                  Tab(text: 'مشاركة حسابي'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tc,
          children: const [
            _SearchByNameTab(),
            _SearchByEmailTab(),
            _ShareProfileTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// بحث بالاسم
// ═══════════════════════════════════════════════════════════════════════════════
class _SearchByNameTab extends StatefulWidget {
  const _SearchByNameTab();

  @override
  State<_SearchByNameTab> createState() => _SearchByNameTabState();
}

class _SearchByNameTabState extends State<_SearchByNameTab>
    with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<FriendUser> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await FriendsService.searchByName(q);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      debugPrint('Firebase Error (searchByName): ${e.toString()}');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _SearchLayout(
      controller: _ctrl,
      focusNode: _focus,
      hint: 'اكتب اسم المستخدم...',
      icon: Icons.person_search_rounded,
      onSearch: _search,
      loading: _loading,
      searched: _searched,
      error: _error,
      results: _results,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// بحث بالإيميل
// ═══════════════════════════════════════════════════════════════════════════════
class _SearchByEmailTab extends StatefulWidget {
  const _SearchByEmailTab();

  @override
  State<_SearchByEmailTab> createState() => _SearchByEmailTabState();
}

class _SearchByEmailTabState extends State<_SearchByEmailTab>
    with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<FriendUser> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await FriendsService.searchByEmail(q);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      debugPrint('Firebase Error (searchByEmail): ${e.toString()}');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _SearchLayout(
      controller: _ctrl,
      focusNode: _focus,
      hint: 'اكتب إيميل المستخدم...',
      icon: Icons.email_rounded,
      keyboardType: TextInputType.emailAddress,
      onSearch: _search,
      loading: _loading,
      searched: _searched,
      error: _error,
      results: _results,
    );
  }
}

// ─── Shared Search Layout ──────────────────────────────────────────────────────
class _SearchLayout extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final VoidCallback onSearch;
  final bool loading;
  final bool searched;
  final String? error;
  final List<FriendUser> results;

  const _SearchLayout({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.keyboardType,
    required this.onSearch,
    required this.loading,
    required this.searched,
    required this.error,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── حقل البحث ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.cardFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.charcoal, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // زر البحث — البحث يتم عند الضغط فقط
              GestureDetector(
                onTap: onSearch,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),

        // ── النتائج ────────────────────────────────────────────────────────
        Expanded(
          child: _buildResults(context),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (!searched) {
      return _SearchHint();
    }
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.charcoal),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('حدث خطأ أثناء البحث',
                  style: TextStyle(color: AppColors.textSecondary)),
              if (error!.contains('index') || error!.contains('Index'))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('قد يحتاج الأمر لإعداد فهرس Firestore',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'لم يُعثر على نتائج',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من صحة المعلومات وحاول مرة أخرى',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: results.length,
      itemBuilder: (ctx, i) =>
          _SearchResultCard(user: results[i]),
    );
  }
}

class _SearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Icon(Icons.manage_search_rounded,
                size: 36, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'ابحث وأضف أصدقاءك',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal),
          ),
          const SizedBox(height: 8),
          const Text(
            'اكتب الاسم أو الإيميل ثم اضغط "بحث"',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Search Result Card ────────────────────────────────────────────────────────
class _SearchResultCard extends StatefulWidget {
  final FriendUser user;
  const _SearchResultCard({required this.user});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  FriendshipStatus _status = FriendshipStatus.none;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final s = await FriendsService.getFriendshipStatus(widget.user.uid);
      if (mounted) setState(() { _status = s; _loading = false; });
    } catch (e) {
      debugPrint('Error in _checkStatus: $e');
      if (mounted) {
        setState(() {
          _status = FriendshipStatus.none;
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _sending = true);
    try {
      await FriendsService.sendFriendRequest(widget.user.uid);
      if (mounted) setState(() { _status = FriendshipStatus.pending; _sending = false; });
    } catch (e) {
      debugPrint('Error sending request: $e');
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _sending = true);
    try {
      await FriendsService.cancelFriendRequest(widget.user.uid);
      if (mounted) setState(() { _status = FriendshipStatus.none; _sending = false; });
    } catch (e) {
      debugPrint('Error canceling request: $e');
      if (mounted) {
        setState(() => _sending = false);
        AppSnackbar.show(
          context: context,
          message: 'تعذر إلغاء الطلب من الخادم. يرجى التأكد من تحديث قواعد حماية Firestore (Security Rules) لتسمح للمرسل بالحذف أو التعديل.',
          isSuccess: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileDetailScreen(
              userId: widget.user.uid,
              initialName: widget.user.fullName,
              initialAvatarIndex: widget.user.avatarIndex,
              initialEmail: widget.user.email,
            ),
          ),
        );
        if (updated == true && mounted) {
          _checkStatus();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            ClipOval(child: FacelessAvatar(index: widget.user.avatarIndex, size: 50)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.fullName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_loading || _sending) {
      return const SizedBox(
        width: 28, height: 28,
        child: CircularProgressIndicator(
            color: AppColors.charcoal, strokeWidth: 2.5),
      );
    }

    switch (_status) {
      case FriendshipStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, size: 14, color: AppColors.green),
            const SizedBox(width: 4),
            Text('صديق', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
          ]),
        );

      case FriendshipStatus.pending:
        return GestureDetector(
          onTap: _cancelRequest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                SizedBox(width: 4),
                Text(
                  'إلغاء الطلب',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent),
                ),
              ],
            ),
          ),
        );

      case FriendshipStatus.received:
        return GestureDetector(
          onTap: () async {
            // الطرف الآخر أرسل الطلب — نقبله
            final reqs = await FriendsService.getIncomingRequests();
            final req = reqs.firstWhere(
              (r) => (r['user'] as FriendUser).uid == widget.user.uid,
              orElse: () => {},
            );
            if (req.isNotEmpty && mounted) {
              await FriendsService.acceptFriendRequest(
                req['requestId'] as String,
                widget.user.uid,
              );
              setState(() => _status = FriendshipStatus.friends);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'قبول',
              style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        );

      case FriendshipStatus.none:
        return GestureDetector(
          onTap: _sendRequest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'إضافة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        );

      case FriendshipStatus.self:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// مشاركة الحساب — QR Code + صورة قابلة للمشاركة
// ═══════════════════════════════════════════════════════════════════════════════
class _ShareProfileTab extends StatefulWidget {
  const _ShareProfileTab();

  @override
  State<_ShareProfileTab> createState() => _ShareProfileTabState();
}

class _ShareProfileTabState extends State<_ShareProfileTab>
    with AutomaticKeepAliveClientMixin {
  final _screenshotCtrl = ScreenshotController();
  bool _sharing = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _share(
      String uid, String name, int avatarIndex, BuildContext ctx) async {
    setState(() => _sharing = true);
    try {
      final Uint8List? image = await _screenshotCtrl.capture(
        pixelRatio: 3.0,
      );
      if (image == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/share_profile.png');
      await file.writeAsBytes(image);

      final link = 'https://onehundred.app/join?uid=$uid';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'انضم إليّ في تحدي المئة يوم! 💰\n$link',
        ),
      );
    } catch (e) {
      if (ctx.mounted) {
        AppSnackbar.show(
          context: ctx,
          message: 'حدث خطأ أثناء المشاركة',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<SavingsProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final name = provider.userProfile?.fullName ?? 'مستخدم';
    final avatarIndex = provider.avatarIndex;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'شارك حسابك مع أصدقائك',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اضغط مشاركة لإرسال بطاقتك الشخصية',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // ── البطاقة المصوَّرة ──────────────────────────────────────────
          Screenshot(
            controller: _screenshotCtrl,
            child: _ShareCard(
              uid: uid,
              name: name,
              avatarIndex: avatarIndex,
            ),
          ),

          const SizedBox(height: 28),

          // ── زر المشاركة ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _sharing ? null : () => _share(uid, name, avatarIndex, context),
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 20),
              label:
                  Text(_sharing ? 'جاري المشاركة...' : 'مشاركة البطاقة'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── رابط المشاركة ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'onehundred.app/join?uid=${uid.length > 12 ? uid.substring(0, 12) : uid}...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ─── بطاقة المشاركة (تُصوَّر كصورة) ──────────────────────────────────────────
class _ShareCard extends StatelessWidget {
  final String uid;
  final String name;
  final int avatarIndex;

  const _ShareCard({
    required this.uid,
    required this.name,
    required this.avatarIndex,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = 'https://onehundred.app/join?uid=$uid';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF3D2B1A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── شعار + اسم التطبيق ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'تحدي المئة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── الأفاتار ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 3),
            ),
            child: ClipOval(
              child: FacelessAvatar(index: avatarIndex, size: 80),
            ),
          ),

          const SizedBox(height: 14),

          // ── الاسم ──────────────────────────────────────────────────────
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'يدعوك للانضمام لتحدي التوفير',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // ── QR Code ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 150,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1A1A1A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── وصف التطبيق ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                const Text(
                  'وفّر يومياً لـ 100 يوم 💰',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'تطبيق تحدي المئة يساعدك على بناء\nعادة التوفير خلال مئة يوم متتالية',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── امسح الكود ─────────────────────────────────────────────────
          Text(
            'امسح الكود للانضمام ←',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
