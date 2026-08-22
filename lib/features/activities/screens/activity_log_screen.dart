import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/theme/app_transitions.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/activities/models/activity_log.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _myActivities = <String, ActivityLog>{};
  final _partnerActivities = <String, ActivityLog>{};
  
  StreamSubscription? _mySub;
  StreamSubscription? _partnerSub;
  
  bool _isLoading = true;
  final PageController _pageController = PageController();
  int _activePageIndex = 0;
  bool _isDeleteMode = false;
  final Set<String> _selectedActivityIds = {};

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _pruneOldActivities();
    final provider = context.read<SavingsProvider>();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _mySub = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      for (var doc in snap.docs) {
        _myActivities[doc.id] = ActivityLog.fromMap(doc.id, doc.data());
      }
      if (mounted) setState(() => _isLoading = false);
    }, onError: (e) {
      debugPrint('Error fetching my activities: $e');
      if (mounted) setState(() => _isLoading = false);
    });

    final partnerUid = provider.partnerUid;
    if ((provider.isCooperativeMode || provider.isCompetitiveMode) && partnerUid != null) {
      _partnerSub = FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen((snap) {
        for (var doc in snap.docs) {
          _partnerActivities[doc.id] = ActivityLog.fromMap(doc.id, doc.data());
        }
        if (mounted) setState(() {});
      }, onError: (e) {
        debugPrint('Error fetching partner activities: $e');
      });
    }
  }

  @override
  void dispose() {
    _mySub?.cancel();
    _partnerSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<ActivityLog> get _mergedActivities {
    final all = [..._myActivities.values, ..._partnerActivities.values];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  List<ActivityLog> get _mySortedActivities {
    final list = _myActivities.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<ActivityLog> get _partnerSortedActivities {
    final list = _partnerActivities.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4EF), // warm background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isDeleteMode ? 'تم تحديد (${_selectedActivityIds.length})' : 'سجل النشاط',
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
            ),
          ),
          leading: _isDeleteMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.charcoal),
                  onPressed: () {
                    setState(() {
                      _isDeleteMode = false;
                      _selectedActivityIds.clear();
                    });
                  },
                )
              : const BackButton(color: AppColors.charcoal),
          actions: [
            if (provider.isCompetitiveMode && _activePageIndex == 1)
              const SizedBox()
            else if (!_isDeleteMode)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _isDeleteMode = true;
                  });
                },
              )
            else ...[
              IconButton(
                icon: Icon(
                  _selectedActivityIds.containsAll(_mySortedActivities.map((a) => a.id))
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  color: AppColors.charcoal,
                ),
                onPressed: () {
                  setState(() {
                    final allMyIds = _mySortedActivities.map((a) => a.id).toSet();
                    if (_selectedActivityIds.containsAll(allMyIds)) {
                      _selectedActivityIds.clear();
                    } else {
                      _selectedActivityIds.addAll(allMyIds);
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                onPressed: _selectedActivityIds.isEmpty
                    ? null
                    : () => _confirmDeleteSelected(),
              ),
            ]
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(SavingsProvider provider) {
    if (provider.isCompetitiveMode && provider.partnerUid != null) {
      return Column(
        children: [
          _buildCompetitiveTabs(provider.partnerName ?? 'المنافس'),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _activePageIndex = index;
                });
              },
              children: [
                _buildTimeline(_mySortedActivities, isMerged: false),
                _buildTimeline(_partnerSortedActivities, isMerged: false, isPartnerPage: true),
              ],
            ),
          ),
        ],
      );
    } else if (provider.isCooperativeMode && provider.partnerUid != null) {
      return _buildTimeline(_mergedActivities, isMerged: true, myUid: FirebaseAuth.instance.currentUser?.uid);
    } else {
      return _buildTimeline(_mySortedActivities, isMerged: false);
    }
  }

  Widget _buildCompetitiveTabs(String partnerName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                // Sliding background pill
                AnimatedPositionedDirectional(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  start: _activePageIndex == 0 ? 4 : tabWidth + 4,
                  top: 4,
                  bottom: 4,
                  width: tabWidth - 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Tab buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          setState(() {
                            _activePageIndex = 0;
                          });
                        },
                        child: Center(
                          child: Text(
                            'سجلي',
                            style: TextStyle(
                              color: _activePageIndex == 0 ? Colors.white : AppColors.charcoal,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          setState(() {
                            _activePageIndex = 1;
                          });
                        },
                        child: Center(
                          child: Text(
                            'سجل خصمي',
                            style: TextStyle(
                              color: _activePageIndex == 1 ? Colors.white : AppColors.charcoal,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeline(List<ActivityLog> activities, {required bool isMerged, String? myUid, bool isPartnerPage = false}) {
    if (activities.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد نشاطات مسجلة بعد',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        final isMine = isMerged ? activity.uid == myUid : !isPartnerPage;

        return IntrinsicHeight(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left side (Time always here)
                SizedBox(
                  width: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        _formatTime(activity.timestamp),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(activity.timestamp),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Timeline Line & Dot
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getColorForType(activity.type).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: _getColorForType(activity.type), width: 2),
                        ),
                        child: Icon(
                          _getIconForType(activity.type),
                          size: 16,
                          color: _getColorForType(activity.type),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.decorArc.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
  
                // Right side (Card)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, left: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCard(activity, showBadge: isMerged && activity.uid != myUid),
                        ),
                        if (_isDeleteMode && isMine) ...[
                          const SizedBox(width: 8),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Checkbox(
                              value: _selectedActivityIds.contains(activity.id),
                              activeColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedActivityIds.add(activity.id);
                                  } else {
                                    _selectedActivityIds.remove(activity.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(ActivityLog activity, {required bool showBadge}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !showBadge ? Colors.white : const Color(0xFFF2F8FC), // soft blue background for partner
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
          border: Border.all(
            color: !showBadge ? Colors.transparent : Colors.blue.withValues(alpha: 0.4), // blue border
            width: !showBadge ? 0.0 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                if (showBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'شريكك',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
          ),
          const SizedBox(height: 4),
          Text(
            activity.description,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (activity.oldValue != null && activity.newValue != null) ...[
            ..._buildChangesList(activity),
          ],
        ],
      ),
    ),
  );
}

  IconData _getIconForType(ActivityType type) {
    switch (type) {
      case ActivityType.deposit: return Icons.account_balance_wallet;
      case ActivityType.updateDeposit: return Icons.edit;
      case ActivityType.deleteDeposit: return Icons.delete;
      case ActivityType.claimCoins: return Icons.monetization_on;
      case ActivityType.watchAd: return Icons.play_circle_fill;
      case ActivityType.useLifebuoy: return Icons.healing;
      case ActivityType.buyLifebuoy: return Icons.shopping_cart;
      case ActivityType.updateGoal: return Icons.flag;
      case ActivityType.addPartner: return Icons.person_add;
      case ActivityType.separatePartner: return Icons.person_remove;
      case ActivityType.pokePartner: return Icons.notifications_active;
      case ActivityType.updateProfile: return Icons.manage_accounts;
      case ActivityType.signUp: return Icons.celebration;
      default: return Icons.local_activity;
    }
  }

  Color _getColorForType(ActivityType type) {
    switch (type) {
      case ActivityType.deposit:
        return AppColors.green;
      case ActivityType.updateDeposit:
        return Colors.orange;
      case ActivityType.deleteDeposit:
        return Colors.red;
      case ActivityType.claimCoins:
        return const Color(0xFFFFD700);
      case ActivityType.watchAd:
        return Colors.purple;
      case ActivityType.useLifebuoy:
        return Colors.redAccent;
      case ActivityType.buyLifebuoy:
        return Colors.blueAccent;
      case ActivityType.updateGoal:
      case ActivityType.updateProfile:
        return Colors.teal;
      case ActivityType.addPartner:
      case ActivityType.separatePartner:
      case ActivityType.pokePartner:
        return Colors.deepOrange;
      case ActivityType.signUp:
        return Colors.indigo;
      case ActivityType.unknown:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    const arabicMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final day = date.day.toString().padLeft(2, '0');
    final month = arabicMonths[date.month - 1];
    return '$day $month';
  }

  String _formatTime(DateTime time) {
    int hour12 = time.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hh = hour12.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour < 12 ? 'صباحاً' : 'مساءً';
    return '$hh:$mm $amPm';
  }

  Future<void> _pruneOldActivities() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activities')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
          .get();
          
      if (snap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('Pruned ${snap.docs.length} old activities.');
      }
    } catch (e) {
      debugPrint('Failed to prune old activities: $e');
    }
  }

  Future<void> deleteActivities(List<String> ids) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    for (var id in ids) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activities')
          .doc(id);
      batch.delete(docRef);
    }
    await batch.commit();
    
    if (mounted) {
      setState(() {
        for (var id in ids) {
          _myActivities.remove(id);
        }
        _selectedActivityIds.clear();
        _isDeleteMode = false;
      });
      AppSnackbar.show(
        context: context,
        message: 'تمت عملية الحذف بنجاح',
        isDelete: true,
      );
    }
  }

  void _confirmDeleteSelected() {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف النشاطات المحددة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف ${_selectedActivityIds.length} من النشاطات المحددة؟', style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSelected();
            },
            child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedActivityIds.toList();
    setState(() => _isLoading = true);
    await deleteActivities(ids);
    setState(() => _isLoading = false);
  }

  List<Widget> _buildChangesList(ActivityLog activity) {
    final oldVals = activity.oldValue!.split('|');
    final newVals = activity.newValue!.split('|');
    
    final widgets = <Widget>[];
    for (int i = 0; i < oldVals.length; i++) {
      if (i >= newVals.length) break;
      final oldVal = oldVals[i];
      final newVal = newVals[i];
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.greenLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    oldVal,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.green, size: 16),
                  ),
                ),
                Expanded(
                  child: Text(
                    newVal,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}
