import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/challenges/models/deposit.dart';
import 'package:one_hunderd/features/profile/models/user_profile.dart';
import 'package:one_hunderd/core/services/notification_service.dart';
import 'package:one_hunderd/features/challenges/services/challenge_service.dart';
import 'package:one_hunderd/features/activities/models/activity_log.dart';

// ─── SharedPrefs keys ─────────────────────────────────────────────────────────
const _kUserProfile = 'user_profile_v1';
const _kDeposits = 'deposits_v1';
const _kLastPokedDate = 'last_poked_date_v1'; // تاريخ آخر نكزة استُقبلت

/// Central state manager for the 100-Day Savings Challenge.
///
/// Supports multiple deposits per day. The 100-day grid represents
/// unique calendar days with at least one deposit. Streak counts
/// consecutive calendar days with deposits.
///
/// All data is persisted to SharedPreferences so it survives app restarts.
class SavingsProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  final List<Deposit> _deposits = [];

  int _currentStreak = 0;
  int _lifebuoys = 0;
  int _lifebuoysUsed = 0;
  DateTime? _lastDepositDate;
  DateTime? _completedAt;

  int _woodenCoins = 0;
  String? _lastDailyClaimDate;
  int _adsWatchedToday = 0;
  int _sharesDoneToday = 0;
  String? _currentDateStr;
  int _avatarIndex = 0;

  StreamSubscription<QuerySnapshot>? _incomingRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _acceptedRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _challengeInvitationsSubscription;
  StreamSubscription<QuerySnapshot>? _cooperativeSessionsListener;
  StreamSubscription<QuerySnapshot>? _competitiveSessionsListener;
  final DateTime _appStartTime = DateTime.now();
  
  bool _hasNewSession = false;
  String? _newSessionType;
  
  bool get hasNewSession => _hasNewSession;
  String? get newSessionType => _newSessionType;
  bool get hasNewCooperativeSession => _hasNewSession;

  final Set<String> _notifiedAcceptedRequestIds = {};

  // ── Poke (نكز) state ───────────────────────────────────────────────────────
  String? _lastPokeDate;       // 'yyyy-M-d' — يوم آخر نكزة أرسلها
  String? _lastPokedDate;      // 'yyyy-M-d' — يوم آخر نكزة استُقبلت (لتجنب التكرار)
  String? _lastPokedBy;        // اسم مَن نكزني
  bool _pendingPokeNotification = false;

  bool get pendingPokeNotification => _pendingPokeNotification;
  String? get lastPokedBy => _lastPokedBy;

  void clearPokeNotification() {
    _pendingPokeNotification = false;
    _lastPokedDate = _todayStr();
    notifyListeners();
  }

  String _todayStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month}-${t.day}';
  }

  String? _activeSessionId;
  String get _activeSessionCollection => _userProfile?.challengeType == 'تنافسي' ? 'competitive_sessions' : 'cooperative_sessions';
  final int _lastKnownPartnerDays = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _activeSessionSubscription;

  String? _partnerUid;
  String? _partnerName;
  int? _partnerAvatarIndex;

  bool _hasPendingSeparationRequest = false;
  String? _separationRequestBy;
  DateTime? _separationRequestCreatedAt;
  bool _isSessionDissolved = false;

  String? get activeSessionId => _activeSessionId;
  bool get isCooperativeMode => _activeSessionId != null && _userProfile?.challengeType == 'تعاوني';
  bool get isCompetitiveMode => _activeSessionId != null && _userProfile?.challengeType == 'تنافسي';

  String? get partnerUid => _partnerUid;
  String? get partnerName => _partnerName;
  int? get partnerAvatarIndex => _partnerAvatarIndex;

  String? get competitivePartnerUid => _partnerUid;
  String? get competitivePartnerName => _partnerName;
  int? get competitivePartnerAvatarIndex => _partnerAvatarIndex;
  int get lastKnownPartnerDays => _lastKnownPartnerDays;

  bool get hasPartnerRequestedSeparation => _hasPendingSeparationRequest && _separationRequestBy != FirebaseAuth.instance.currentUser?.uid && !_isSessionDissolved;
  bool get hasCurrentRequestedSeparation => _hasPendingSeparationRequest && _separationRequestBy == FirebaseAuth.instance.currentUser?.uid && !_isSessionDissolved;

  bool get canForceSeparate {
    if (!hasCurrentRequestedSeparation || _separationRequestCreatedAt == null) return false;
    return DateTime.now().difference(_separationRequestCreatedAt!).inHours >= 48;
  }
  bool get isSessionDissolved => _isSessionDissolved;

  Map<String, String> _cooperativeUserNames = {};
  Map<String, String> get cooperativeUserNames => _cooperativeUserNames;

  // ── Getters ──────────────────────────────────────────────────────────────

  UserProfile? get userProfile => _userProfile;
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null && _userProfile != null;
  List<Deposit> get deposits => List.unmodifiable(_deposits.where((d) => d.notes != 'lifebuoy'));

  /// All unique calendar dates that have at least one deposit, sorted ascending.
  List<DateTime> get uniqueDepositDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final d in _deposits) {
      if (d.notes == 'lifebuoy') continue;
      final key = '${d.dateOnly.year}-${d.dateOnly.month}-${d.dateOnly.day}';
      if (seen.add(key)) {
        dates.add(d.dateOnly);
      }
    }
    dates.sort();
    return dates;
  }

  /// Number of unique days with deposits (grid cells filled, max 100).
  int get completedDays => uniqueDepositDates.length.clamp(0, 100);

  /// Whether grid cell [dayNumber] (1-based) is completed.
  bool isDayCompleted(int dayNumber) => dayNumber <= completedDays;

  /// Get all deposits for a specific grid day number (1-based).
  List<Deposit> getDepositsForDay(int dayNumber) {
    final dates = uniqueDepositDates;
    if (dayNumber < 1 || dayNumber > dates.length) return [];
    final targetDate = dates[dayNumber - 1];
    return _deposits.where((d) => d.dateOnly == targetDate && d.notes != 'lifebuoy').toList();
  }

  /// Get the calendar date for a specific grid day number.
  DateTime? getDateForDay(int dayNumber) {
    final dates = uniqueDepositDates;
    if (dayNumber < 1 || dayNumber > dates.length) return null;
    return dates[dayNumber - 1];
  }

  /// Total amount saved for a specific grid day.
  double totalForDay(int dayNumber) {
    return getDepositsForDay(dayNumber).fold(0.0, (s, d) => s + d.amount);
  }

  /// Current streak: consecutive calendar days ending at today (or yesterday).
  int get currentStreak => _currentStreak;
  
  int get lifebuoys => _lifebuoys;
  int get lifebuoysUsed => _lifebuoysUsed;
  DateTime? get lastDepositDate => _lastDepositDate;
  DateTime? get completedAt => _completedAt;

  int get woodenCoins => _woodenCoins;
  String? get lastDailyClaimDate => _lastDailyClaimDate;
  int get adsWatchedToday => _adsWatchedToday;
  int get sharesDoneToday => _sharesDoneToday;
  int get avatarIndex => _avatarIndex;

  /// الفجوة بالأيام بين آخر إيداع (أو طوق) واليوم الحالي
  int get daysSinceLastDeposit {
    if (_lastDepositDate == null) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return todayOnly.difference(_lastDepositDate!).inDays;
  }

  /// تكلفة استخدام طوق النجاة بناءً على عدد الأيام الفائتة
  /// gap=2 (فات يوم) → 1 طوق | gap=3 (فات يومان) → 2 طوق | غير ذلك → 0
  int get lifebuoyCost {
    final gap = daysSinceLastDeposit;
    if (gap == 2) return 1;
    if (gap == 3) return 2;
    return 0;
  }

  /// أطول ستريك متواصل تاريخياً (محسوب من قائمة الإيداعات)
  int get longestStreak {
    if (_deposits.isEmpty) return _currentStreak;
    final days = _deposits
        .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) return _currentStreak;
    int longest = 1;
    int current = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest > _currentStreak ? longest : _currentStreak;
  }

  /// نسبة الالتزام من تاريخ أول إيداع حتى اليوم (0.0–1.0)
  double get commitmentRate {
    if (_deposits.isEmpty) return 0.0;
    final days = _deposits
        .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
        .toSet()
        .toList()
      ..sort();
    final firstDay = days.first;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final totalDays = todayOnly.difference(firstDay).inDays + 1;
    return totalDays > 0 ? days.length / totalDays : 0.0;
  }

  /// أيام التحدي التي يوجد فيها إيداع واحد على الأقل (للتقويم)
  Set<DateTime> get depositDays => _deposits
      .where((d) => d.notes != 'lifebuoy')
      .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
      .toSet();

  /// أيام التحدي التي تم حمايتها بطوق نجاة
  Set<DateTime> get protectedDays => _deposits
      .where((d) => d.notes == 'lifebuoy')
      .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
      .toSet();

  /// الستريك في خطر غير قابل للإنقاذ (gap >= 4)
  bool get isStreakBroken {
    if (_lastDepositDate == null || _currentStreak == 0) return false;
    return daysSinceLastDeposit >= 4;
  }

  /// الستريك في خطر وقابل للإنقاذ (يومان أو ثلاثة بدون إيداع)
  bool get isStreakInDanger {
    if (_lastDepositDate == null || _currentStreak == 0) return false;
    final gap = daysSinceLastDeposit;
    return gap == 2 || gap == 3;
  }

  Future<void> _checkAndAutoResetStreak() async {
    if (_currentStreak > 0 && _lastDepositDate != null && daysSinceLastDeposit >= 4) {
      _currentStreak = 0;
      await _persist();
    }
  }

  int _calculateOldStreak() {
    if (_deposits.isEmpty) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Group deposits by date
    final depositsByDate = <String, List<Deposit>>{};
    for (final d in _deposits) {
      final key = '${d.dateOnly.year}-${d.dateOnly.month}-${d.dateOnly.day}';
      depositsByDate.putIfAbsent(key, () => []).add(d);
    }

    DateTime checkDate = todayOnly;
    final todayKey = '${todayOnly.year}-${todayOnly.month}-${todayOnly.day}';
    
    // If today has no deposits at all, we start checking from yesterday
    if (!depositsByDate.containsKey(todayKey)) {
      checkDate = todayOnly.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (true) {
      final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      if (!depositsByDate.containsKey(key)) {
        break; // No deposit and no lifebuoy on this day, streak breaks!
      }
      
      final dayDeps = depositsByDate[key]!;
      final isLifebuoyDay = dayDeps.every((d) => d.notes == 'lifebuoy');
      
      if (!isLifebuoyDay) {
        streak++;
      }
      
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _updateStreakAndLastDate() {
    _currentStreak = _calculateOldStreak();
    if (_deposits.isEmpty) {
      _lastDepositDate = null;
    } else {
      DateTime? maxDate;
      for (final d in _deposits) {
        if (maxDate == null || d.dateOnly.isAfter(maxDate)) {
          maxDate = d.dateOnly;
        }
      }
      _lastDepositDate = maxDate;
    }
  }

  /// Whether the challenge is complete (100 unique days).
  bool get isComplete => completedDays >= 100;

  /// Total amount saved across all deposits.
  double get totalSaved => _deposits.fold(0.0, (t, d) => t + d.amount);

  int get remainingDays => 100 - completedDays;
  double get progress => completedDays / 100;

  /// Today's deposits.
  List<Deposit> get todayDeposits {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return _deposits.where((d) => d.dateOnly == todayOnly).toList();
  }

  double get todayTotal => todayDeposits.fold(0.0, (s, d) => s + d.amount);
  bool get hasTodayDeposit => todayDeposits.isNotEmpty;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initializeAuthAndData() async {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        init();
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });

    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user != null) {
      await init();
    }
  }

  String _cleanName(String name) {
    if (name.contains(' 🤝 ')) {
      return name.split(' 🤝 ').first.trim();
    }
    return name.trim();
  }

  /// Loads all persisted data from Firestore (Offline persistence handles cache automatically).
  /// Call once from main() before runApp.
  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    final data = docSnap.data() ?? <String, dynamic>{};

    // هجرة ذاتية: إضافة حقل createdAt في Firestore في حال عدم وجوده
    if (!data.containsKey('createdAt')) {
      final creationTime = user.metadata.creationTime ?? DateTime.now();
      await docRef.set({
        'createdAt': Timestamp.fromDate(creationTime),
      }, SetOptions(merge: true));
      data['createdAt'] = Timestamp.fromDate(creationTime);
    }

    // Load user profile
    bool needsMigration = false;
    if (data.containsKey(_kUserProfile) && data[_kUserProfile] != null) {
      try {
        final profileMap = Map<String, dynamic>.from(data[_kUserProfile] as Map<String, dynamic>);
        final rawFullName = profileMap['fullName'] as String? ?? '';
        if (rawFullName.contains(' 🤝 ')) {
          profileMap['fullName'] = _cleanName(rawFullName);
          needsMigration = true;
        }
        
        _userProfile = UserProfile.fromJson(profileMap);
        
        // If lower fields are missing in Firestore for this profile, trigger migration
        if (!profileMap.containsKey('fullName_lower') || !profileMap.containsKey('contact_lower')) {
          needsMigration = true;
        }
      } catch (_) {
        _userProfile = null;
      }
    }

    // Fallback if user profile wasn't saved properly before
    if (_userProfile == null) {
      _userProfile = UserProfile(
        fullName: 'صديق التحدي',
        gender: 'Male',
        contact: user.email ?? '',
        financialGoal: 5050.0,
        maritalStatus: 'شاب',
        goal: 'توفير',
        challengeType: 'فردي',
      );
      needsMigration = true;
    }

    if (needsMigration) {
      _persist().catchError((e) {
        debugPrint('Auto-migration/Persist failed: $e');
      });
    }

    // ─── التحقق من وجود جلسة تعاونية أو تنافسية نشطة عند التشغيل ───
    final sessionSnap = await ChallengeService.getActiveSession(user.uid);
    if (sessionSnap != null) {
      _activeSessionId = sessionSnap.id;
      final isCompetitiveSession = sessionSnap.reference.parent.id == 'competitive_sessions';
      final expectedType = isCompetitiveSession ? 'تنافسي' : 'تعاوني';

      if (_userProfile?.challengeType != expectedType) {
        _userProfile = UserProfile(
          fullName: _userProfile?.fullName ?? 'صديق التحدي',
          gender: _userProfile?.gender ?? 'Male',
          contact: _userProfile?.contact ?? '',
          financialGoal: _userProfile?.financialGoal ?? 5050.0,
          maritalStatus: _userProfile?.maritalStatus ?? 'شاب',
          goal: _userProfile?.goal ?? 'توفير',
          challengeType: expectedType,
          birthDate: _userProfile?.birthDate,
        );
        await docRef.set({
          'user_profile_v1': {
            'challengeType': expectedType,
          },
          'activeSessionId': _activeSessionId,
        }, SetOptions(merge: true));
      }
      
      _startActiveSessionListener(_activeSessionId!, isCompetitive: _userProfile?.challengeType == 'تنافسي');
      
      // تحميل بيانات الشريك فوراً من مستند المستخدم قبل أن يُحمَّل الـ listener
      _partnerUid = data['cooperativePartnerUid'] as String?;
      _partnerName = data['cooperativePartnerName'] as String?;
      _partnerAvatarIndex = data['cooperativePartnerAvatarIndex'] as int?;
      _avatarIndex = data['avatarIndex'] as int? ?? 0;
      
      // إذا لم تكن بيانات الشريك محفوظة في مستند المستخدم، نحملها من الجلسة مباشرة
      if (_partnerUid == null || _partnerName == null) {
        final sessionData = sessionSnap.data();
        final namesMap = sessionData?['userNames'] as Map<String, dynamic>? ?? {};
        final avatarsMap = sessionData?['userAvatars'] as Map<String, dynamic>? ?? {};
        for (final uid in namesMap.keys) {
          if (uid != user.uid) {
            _partnerUid = uid;
            _partnerName = namesMap[uid]?.toString();
            if (avatarsMap.containsKey(uid)) {
              _partnerAvatarIndex = (avatarsMap[uid] as num).toInt();
            }
            break;
          }
        }
      }

      // تحميل عدادات المكافآت الفردية لمنع تصفيرها عند مزامنة الـ listener
      _lastDailyClaimDate = data['last_daily_claim_v1'] as String?;
      _adsWatchedToday = data['ads_watched_v1'] as int? ?? 0;
      _sharesDoneToday = data['shares_done_v1'] as int? ?? 0;
      _currentDateStr = data['current_date_str_v1'] as String?;
      checkAndResetDailyCounters();

      // تحميل الإيداعات والإحصائيات التعاونية أو التنافسية فوراً لتجنب أي وميض أو شاشة فارغة
      if (isCompetitiveSession) {
        // في التحدي التنافسي، يتم تحميل الإحصائيات الفردية من ملف المستخدم نفسه
        _currentStreak = data['current_streak_v1'] as int? ?? 0;
        _lifebuoys = data['lifebuoys_v1'] as int? ?? 0;
        _lifebuoysUsed = data['lifebuoys_used_v1'] as int? ?? 0;
        _woodenCoins = data['wooden_coins_v1'] as int? ?? 0;
        final lastDateStr = data['last_deposit_date_v1'] as String?;
        if (lastDateStr != null) {
          _lastDepositDate = DateTime.tryParse(lastDateStr);
        } else {
          _lastDepositDate = null;
        }

        final completedAtTs = data['completedAt'] as Timestamp?;
        if (completedAtTs != null) {
          _completedAt = completedAtTs.toDate();
        } else {
          _completedAt = null;
        }

        final rawDeps = data[_kDeposits] as List<dynamic>? ?? [];
        _deposits.clear();
        for (final raw in rawDeps) {
          try {
            _deposits.add(Deposit.fromJson(raw as Map<String, dynamic>));
          } catch (_) {}
        }
      } else {
        // في التحدي التعاوني، يتم تحميل البيانات المشتركة من مستند الجلسة
        final sessionData = sessionSnap.data() ?? {};
        final rawDeps = sessionData['deposits'] as List<dynamic>? ?? [];
        _deposits.clear();
        for (final raw in rawDeps) {
          try {
            _deposits.add(Deposit.fromJson(raw as Map<String, dynamic>));
          } catch (_) {}
        }

        _updateStreakAndLastDate();
        _lifebuoys = sessionData['lifebuoys'] as int? ?? 0;
        _woodenCoins = sessionData['woodenCoins'] as int? ?? 0;

        final completedAtTs = sessionData['completedAt'] as Timestamp?;
        if (completedAtTs != null) {
          _completedAt = completedAtTs.toDate();
        } else {
          _completedAt = null;
        }
      }
      
      _startFriendsListeners(user.uid);
      await _checkAndAutoResetStreak();
      notifyListeners();
      return;
    } else {
      _activeSessionSubscription?.cancel();
      _activeSessionSubscription = null;
      _activeSessionId = null;
    }

    // Load streak and lifebuoys
    _currentStreak = data['current_streak_v1'] as int? ?? 0;
    _lifebuoys = data['lifebuoys_v1'] as int? ?? 0;
    _lifebuoysUsed = data['lifebuoys_used_v1'] as int? ?? 0;
    final lastDateStr = data['last_deposit_date_v1'] as String?;
    if (lastDateStr != null) {
      _lastDepositDate = DateTime.tryParse(lastDateStr);
    }

    final completedAtTs = data['completedAt'] as Timestamp?;
    if (completedAtTs != null) {
      _completedAt = completedAtTs.toDate();
    }

    // Load coins and daily counters
    _woodenCoins = data['wooden_coins_v1'] as int? ?? 0;
    _lastDailyClaimDate = data['last_daily_claim_v1'] as String?;
    _adsWatchedToday = data['ads_watched_v1'] as int? ?? 0;
    _sharesDoneToday = data['shares_done_v1'] as int? ?? 0;
    _currentDateStr = data['current_date_str_v1'] as String?;
    _avatarIndex = data['avatarIndex'] as int? ?? 0;
    _partnerUid = data['cooperativePartnerUid'] as String?;
    _partnerName = data['cooperativePartnerName'] as String?;
    _partnerAvatarIndex = data['cooperativePartnerAvatarIndex'] as int?;
    
    checkAndResetDailyCounters();

    // Load deposits
    final depositsList = data[_kDeposits] as List<dynamic>? ?? [];
    _deposits.clear();
    for (final raw in depositsList) {
      try {
        _deposits.add(Deposit.fromJson(raw as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupted entry
      }
    }

    _updateStreakAndLastDate();
    await _checkAndAutoResetStreak();

    if (isComplete && _completedAt == null) {
      _completedAt = _lastDepositDate ?? DateTime.now();
    }
    await _persist();

    _startFriendsListeners(user.uid);
    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  void _startActiveSessionListener(String sessionId, {bool isCompetitive = false}) {
    _activeSessionSubscription?.cancel();
    _activeSessionSubscription = ChallengeService.activeSessionStream(sessionId, isCompetitive: isCompetitive).listen((doc) async {
      if (!doc.exists) {
        // Session document deleted — treat as dissolved
        _handleSessionDissolved();
        return;
      }
      final data = doc.data() ?? {};

      // Check for session dissolution first
      final sessionStatus = data['status'] as String?;
      if (sessionStatus == 'dissolved') {
        _handleSessionDissolved();
        return; // Stop parsing since the session is dissolved
      } else {
        _isSessionDissolved = false;
      }

      // Parse separation request
      final sepReq = data['separationRequest'] as Map<String, dynamic>?;
      if (sepReq != null) {
        _hasPendingSeparationRequest = sepReq['status'] == 'pending';
        _separationRequestBy = sepReq['requestedBy'] as String?;
        _separationRequestCreatedAt = (sepReq['createdAt'] as Timestamp?)?.toDate();
      } else {
        _hasPendingSeparationRequest = false;
        _separationRequestBy = null;
        _separationRequestCreatedAt = null;
      }

      // Parse shared user names
      final namesMap = data['userNames'] as Map<String, dynamic>? ?? {};
      _cooperativeUserNames = namesMap.map((key, value) => MapEntry(key, value.toString()));

      // Parse shared avatars and update partner info
      final avatarsMap = data['userAvatars'] as Map<String, dynamic>? ?? {};
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First try to find partnerUid from the 'users' list
        final usersList = data['users'] as List<dynamic>? ?? [];
        for (final u in usersList) {
          final uidStr = u.toString();
          if (uidStr != user.uid) {
            _partnerUid = uidStr;
            break;
          }
        }
        
        // If not found in users list, fallback to keys of namesMap
        if (_partnerUid == null) {
          for (final uid in namesMap.keys) {
            if (uid != user.uid) {
              _partnerUid = uid;
              break;
            }
          }
        }

        // Set immediate local names/avatars from the session document
        if (_partnerUid != null) {
          if (namesMap.containsKey(_partnerUid)) {
            _partnerName = _cleanName(namesMap[_partnerUid].toString());
          }
          if (avatarsMap.containsKey(_partnerUid)) {
            _partnerAvatarIndex = (avatarsMap[_partnerUid] as num).toInt();
          }

          // Direct query to the partner's user document to guarantee we get the real name and avatar
          FirebaseFirestore.instance.collection('users').doc(_partnerUid).get().then((partnerDoc) {
            if (partnerDoc.exists) {
              final pData = partnerDoc.data() ?? {};
              final pProfile = pData['user_profile_v1'] as Map<String, dynamic>? ?? {};
              final rawRealName = pProfile['fullName'] as String?;
              final realName = rawRealName != null ? _cleanName(rawRealName) : null;
              final realAvatar = pData['avatarIndex'] as int?;
              
              bool changed = false;
              if (realName != null && realName != _partnerName) {
                _partnerName = realName;
                changed = true;
              }
              if (realAvatar != null && realAvatar != _partnerAvatarIndex) {
                _partnerAvatarIndex = realAvatar;
                changed = true;
              }
              if (changed) {
                notifyListeners();
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                if (myUid != null) {
                  FirebaseFirestore.instance.collection('users').doc(myUid).update({
                    'cooperativePartnerName': _partnerName,
                    'cooperativePartnerAvatarIndex': _partnerAvatarIndex,
                  }).catchError((_) {});
                }
              }
            }
          }).catchError((_) {});
        }
      }

      if (!isCompetitive) {
        // Parse shared deposits
        final rawDeps = data['deposits'] as List<dynamic>? ?? [];
        _deposits.clear();
        for (final raw in rawDeps) {
          try {
            _deposits.add(Deposit.fromJson(raw as Map<String, dynamic>));
          } catch (_) {}
        }

        _updateStreakAndLastDate();
        _lifebuoys = data['lifebuoys'] as int? ?? 0;
        _woodenCoins = data['woodenCoins'] as int? ?? 0;

        // Sync shared financial goal (always = inviter's goal)
        final sharedGoal = (data['financialGoal'] as num?)?.toDouble();
        if (sharedGoal != null) {
          // الجلسة تحتوي على الهدف — طبّقه مباشرةً
          if (_userProfile != null && _userProfile!.financialGoal != sharedGoal) {
            _userProfile!.financialGoal = sharedGoal;
          }
        } else {
          // جلسة قديمة لا تحتوي على financialGoal — ارجع لملف المرسل واكتبه للجلسة (مرة واحدة فقط)
          final inviterUid = data['inviterUid'] as String?;
          if (inviterUid != null) {
            FirebaseFirestore.instance.collection('users').doc(inviterUid).get().then((inviterDoc) {
              if (!inviterDoc.exists) return;
              final inviterGoal = ((inviterDoc.data()?['user_profile_v1'] as Map<String, dynamic>?)?['financialGoal'] as num?)?.toDouble();
              if (inviterGoal == null) return;
              // اكتب في الجلسة لكي لا نحتاج هذا الطلب مستقبلاً
              FirebaseFirestore.instance
                  .collection('cooperative_sessions')
                  .doc(sessionId)
                  .update({'financialGoal': inviterGoal});
              // طبّق محلياً فوراً بدون انتظار Firestore
              if (_userProfile != null && _userProfile!.financialGoal != inviterGoal) {
                _userProfile!.financialGoal = inviterGoal;
                notifyListeners();
              }
            });
          }
        }

        final completedAtTs = data['completedAt'] as Timestamp?;
        if (completedAtTs != null) {
          _completedAt = completedAtTs.toDate();
        } else {
          _completedAt = null;
        }
      }

      // ─── Self-Healing Sync: Update ONLY MY OWN user document ─────────────────
      // Each device has write permission only on its own users/{uid} document.
      // The partner's device will independently run this same logic on their
      // side when they receive the same session snapshot — keeping both in sync
      // without any cross-user writes.
      if (user != null) {
        final myUserDocUpdates = <String, dynamic>{
          'activeSessionId': _activeSessionId,
          'cooperativePartnerUid': _partnerUid,
          'cooperativePartnerName': _partnerName != null ? _cleanName(_partnerName!) : null,
          'cooperativePartnerAvatarIndex': _partnerAvatarIndex,
          'user_profile_v1': {
            'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
            'challengeType': isCompetitive ? 'تنافسي' : 'تعاوني',
          },
        };
        if (!isCompetitive) {
          myUserDocUpdates.addAll({
            'current_streak_v1': _currentStreak,
            'completed_days_count': completedDays,
            'is_complete_v1': isComplete,
            'completedAt': _completedAt != null ? Timestamp.fromDate(_completedAt!) : FieldValue.delete(),
            'lifebuoys_v1': _lifebuoys,
            'wooden_coins_v1': _woodenCoins,
            'last_deposit_date_v1': _lastDepositDate != null ? _lastDepositDate!.toIso8601String() : FieldValue.delete(),
            'last_daily_claim_v1': _lastDailyClaimDate ?? FieldValue.delete(),
            'ads_watched_v1': _adsWatchedToday,
            'shares_done_v1': _sharesDoneToday,
            'current_date_str_v1': _currentDateStr ?? FieldValue.delete(),
          });
        }
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(myUserDocUpdates, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('Error in self-healing user doc sync: $e');
        });
      }

      // ─── Poke detection (competitive only) ─────────────────────────────────────────
      if (isCompetitive && user != null) {
        final myPokeKey = 'poke_to_${user.uid}';
        final pokeReq = data[myPokeKey] as Map<String, dynamic>?;
        if (pokeReq != null) {
          final pokeDate = pokeReq['date'] as String?;
          // نحمّل _lastPokedDate من SharedPreferences إذا كان فارغاً
          // (يحدث عند أول تشغيل بعد إعادة تشغيل التطبيق)
          if (_lastPokedDate == null) {
            final prefs = await SharedPreferences.getInstance();
            _lastPokedDate = prefs.getString(_kLastPokedDate);
          }
          if (pokeDate != null && pokeDate != _lastPokedDate) {
            _lastPokedDate = pokeDate;
            _lastPokedBy = pokeReq['fromName'] as String? ?? _partnerName ?? 'الخصم';
            _pendingPokeNotification = true;
            // حفظ التاريخ في SharedPreferences لمنع إعادة الإشعار عند إعادة التشغيل
            SharedPreferences.getInstance().then(
              (prefs) => prefs.setString(_kLastPokedDate, pokeDate),
            );
            NotificationService().showInstantNotification(
              'لكزك خصمك! 👇',
              'نكزك $_lastPokedBy لتذكرك بالإيداع اليومي! 💰',
            );
          }
        }
      }

      notifyListeners();
    });
  }

  /// Called when the cooperative session is detected as dissolved (by listener or on init).
  /// Resets all cooperative state on THIS device only and updates own user document
  /// to individual mode so the app doesn't get stuck in cooperative state.
  void _handleSessionDissolved() {
    _isSessionDissolved = true;
    notifyListeners();

    // Stop the session listener — no more updates needed
    _activeSessionSubscription?.cancel();
    _activeSessionSubscription = null;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _activeSessionId == null) return;

    final wasCompetitive = isCompetitiveMode;
    final sessionCollection = wasCompetitive ? 'competitive_sessions' : 'cooperative_sessions';
    
    FirebaseFirestore.instance
        .collection(sessionCollection)
        .doc(_activeSessionId!)
        .get()
        .then((sessionDoc) {
      if (!sessionDoc.exists) return;
      final sessionData = sessionDoc.data() ?? {};

      // The partnerSplit field contains the initiator's data prepared by the approver.
      // Apply it if this device belongs to the initiator (uid matches partnerSplit.uid).
      final partnerSplit = sessionData['partnerSplit'] as Map<String, dynamic>?;
      if (partnerSplit != null && partnerSplit['uid'] == myUid) {
        // I am the initiator — apply my split data
        final rawDeps = partnerSplit['deposits'] as List<dynamic>? ?? [];
        final deps = rawDeps.map((r) {
          try { return Deposit.fromJson(r as Map<String, dynamic>); } catch (_) { return null; }
        }).whereType<Deposit>().toList();

        final lastDepStr = partnerSplit['lastDepositDate'] as String?;
        final updates = <String, dynamic>{
          'user_profile_v1': {
            'challengeType': 'فردي',
            'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
          },
          _kDeposits: deps.map((d) => d.toJson()).toList(),
          'current_streak_v1': partnerSplit['streak'] as int? ?? 0,
          'lifebuoys_v1': partnerSplit['lifebuoys'] as int? ?? 0,
          'wooden_coins_v1': partnerSplit['woodenCoins'] as int? ?? 0,
          'completed_days_count': partnerSplit['completedDays'] as int? ?? 0,
          'is_complete_v1': (partnerSplit['completedDays'] as int? ?? 0) >= 100,
          'last_deposit_date_v1': lastDepStr ?? FieldValue.delete(),
          'activeSessionId': FieldValue.delete(),
          'cooperativePartnerUid': FieldValue.delete(),
          'cooperativePartnerName': FieldValue.delete(),
          'cooperativePartnerAvatarIndex': FieldValue.delete(),
        };
        FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .set(updates, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('_handleSessionDissolved partnerSplit apply error: $e');
        });
      } else {
        // I am the approver or no partnerSplit — just clear cooperative fields
        FirebaseFirestore.instance.collection('users').doc(myUid).set({
          'user_profile_v1': {
            'challengeType': 'فردي',
            'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
          },
          'activeSessionId': FieldValue.delete(),
          'cooperativePartnerUid': FieldValue.delete(),
          'cooperativePartnerName': FieldValue.delete(),
          'cooperativePartnerAvatarIndex': FieldValue.delete(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('_handleSessionDissolved user doc cleanup error: $e');
        });
      }
    }).catchError((e) {
      debugPrint('_handleSessionDissolved session fetch error: $e');
      // Fallback: just clear cooperative fields on own document
      FirebaseFirestore.instance.collection('users').doc(myUid).set({
        'user_profile_v1': {
          'challengeType': 'فردي',
          'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
        },
        'activeSessionId': FieldValue.delete(),
        'cooperativePartnerUid': FieldValue.delete(),
        'cooperativePartnerName': FieldValue.delete(),
        'cooperativePartnerAvatarIndex': FieldValue.delete(),
      }, SetOptions(merge: true)).catchError((_) {});
    });
  }

  Future<void> _persistCooperative({Deposit? newDeposit}) async {
    if (_activeSessionId == null) return;

    final docRef = FirebaseFirestore.instance.collection('cooperative_sessions').doc(_activeSessionId);
    
    final updateData = <String, dynamic>{
      if (newDeposit != null)
        'deposits': FieldValue.arrayUnion([newDeposit.toJson()])
      else
        'deposits': _deposits.map((d) => d.toJson()).toList(),
      'currentStreak': _currentStreak,
      'lifebuoys': _lifebuoys,
      'woodenCoins': _woodenCoins,
      'lastDepositDate': _lastDepositDate != null ? _lastDepositDate!.toIso8601String() : FieldValue.delete(),
      'completedAt': _completedAt != null ? Timestamp.fromDate(_completedAt!) : FieldValue.delete(),
    };

    await docRef.set(updateData, SetOptions(merge: true));

    // Update ONLY MY OWN user document in the users collection.
    // Each device has write permission only on its own users/{uid} doc.
    // The partner's device will update their own doc when the session listener
    // fires on their side (both devices listen to the same cooperative_sessions doc).
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      // ── إنشاء نسخة الملف الشخصي مع حقول البحث ──────────────────────────────
      Map<String, dynamic>? profileData;
      if (_userProfile != null) {
        profileData = _userProfile!.toJson();
        profileData['fullName_lower'] = (_userProfile!.fullName).toLowerCase().trim();
        profileData['contact_lower'] = (_userProfile!.contact).toLowerCase().trim();
      }

      final myUserDocUpdates = <String, dynamic>{
        _kUserProfile: profileData ?? FieldValue.delete(),
        'current_streak_v1': _currentStreak,
        'completed_days_count': completedDays,
        'is_complete_v1': isComplete,
        'completedAt': _completedAt != null ? Timestamp.fromDate(_completedAt!) : FieldValue.delete(),
        'lifebuoys_v1': _lifebuoys,
        'lifebuoys_used_v1': _lifebuoysUsed,
        'wooden_coins_v1': _woodenCoins,
        'last_deposit_date_v1': _lastDepositDate != null ? _lastDepositDate!.toIso8601String() : FieldValue.delete(),
        'last_daily_claim_v1': _lastDailyClaimDate ?? FieldValue.delete(),
        'ads_watched_v1': _adsWatchedToday,
        'shares_done_v1': _sharesDoneToday,
        'current_date_str_v1': _currentDateStr ?? FieldValue.delete(),
        'activeSessionId': _activeSessionId,
        'cooperativePartnerUid': _partnerUid,
        'cooperativePartnerName': _partnerName != null ? _cleanName(_partnerName!) : null,
        'cooperativePartnerAvatarIndex': _partnerAvatarIndex,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .set(myUserDocUpdates, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('Error updating my user doc in _persistCooperative: $e');
      });

      // 🔥 تحديث مستند الشريك أيضاً للحفاظ على تزامن لوحة الصدارة 🔥
      if (_partnerUid != null) {
        final partnerDocUpdates = <String, dynamic>{
          'current_streak_v1': _currentStreak,
          'completed_days_count': completedDays,
          'is_complete_v1': isComplete,
          'completedAt': _completedAt != null ? Timestamp.fromDate(_completedAt!) : FieldValue.delete(),
          'lifebuoys_v1': _lifebuoys,
          'wooden_coins_v1': _woodenCoins,
          'last_deposit_date_v1': _lastDepositDate != null ? _lastDepositDate!.toIso8601String() : FieldValue.delete(),
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_partnerUid!)
            .set(partnerDocUpdates, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('Error updating partner user doc: $e');
        });
      }
    }
  }

  // ── Cooperative Separation Methods ───────────────────────────────────────

  /// The current user requests separation from the cooperative challenge.
  /// Writes a pending separation request to Firestore — does NOT immediately
  /// dissolve the session. The partner must also approve.
  Future<void> requestSeparation() async {
    if (_activeSessionId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await FirebaseFirestore.instance
        .collection(_activeSessionCollection)
        .doc(_activeSessionId)
        .set({
      'separationRequest': {
        'requestedBy': myUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    
    await _logActivity(
      type: ActivityType.separatePartner,
      title: 'طلب انفصال',
      description: 'لقد قمت بإرسال طلب انفصال عن التحدي التعاوني',
    );
  }

  /// The partner rejects the separation request.
  /// Deletes the separationRequest field from the session so the challenge
  /// continues normally for both parties.
  Future<void> rejectSeparation() async {
    if (_activeSessionId == null) return;

    await FirebaseFirestore.instance
        .collection(_activeSessionCollection)
        .doc(_activeSessionId)
        .update({
      'separationRequest': FieldValue.delete(),
    });
  }

  /// Calculates the streak for a given list of deposits (used for individual
  /// streak recalculation after separation).
  int _calculateStreakForDeposits(List<Deposit> deps) {
    if (deps.isEmpty) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateSet = <DateTime>{};
    for (final d in deps) {
      dateSet.add(d.dateOnly);
    }
    DateTime checkDate = todayOnly;
    if (!dateSet.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!dateSet.contains(checkDate)) return 0;
    }
    int streak = 0;
    while (dateSet.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The partner approves the separation request.
  /// IMPORTANT: This method only writes to:
  ///   a) MY OWN user document (receiver/approver)
  ///   b) The cooperative_sessions document (marks it dissolved)
  /// The INITIATOR's user document is cleaned up by their own device
  /// when their _startActiveSessionListener fires and detects 'dissolved'.
  Future<void> approveSeparation() async {
    if (_activeSessionId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _partnerUid == null) return;

    final wasCompetitive = isCompetitiveMode;
    final sessionCollection = wasCompetitive ? 'competitive_sessions' : 'cooperative_sessions';

    if (wasCompetitive) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .set({
        'user_profile_v1': {
          'challengeType': 'فردي',
          'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
        },
        'activeSessionId': FieldValue.delete(),
        'cooperativePartnerUid': FieldValue.delete(),
        'cooperativePartnerName': FieldValue.delete(),
        'cooperativePartnerAvatarIndex': FieldValue.delete(),
      }, SetOptions(merge: true));

      await ChallengeService.dissolveChallengeInvitations(myUid, _partnerUid!);

      await _logActivity(
        type: ActivityType.separatePartner,
        title: 'قبول الانفصال',
        description: 'لقد وافقت على طلب الانفصال وعدت للتحدي الفردي',
      );

      await FirebaseFirestore.instance
          .collection('competitive_sessions')
          .doc(_activeSessionId!)
          .update({
        'status': 'dissolved',
        'dissolvedAt': FieldValue.serverTimestamp(),
        'separationRequest': FieldValue.delete(),
      });
      return;
    }

    // ── 1. Fetch latest session data ────────────────────────────────────────
    final sessionDoc = await FirebaseFirestore.instance
        .collection('cooperative_sessions')
        .doc(_activeSessionId)
        .get();

    if (!sessionDoc.exists) return;
    final sessionData = sessionDoc.data() ?? {};

    // ── 2. Parse all deposits ────────────────────────────────────────────────
    final rawDeps = sessionData['deposits'] as List<dynamic>? ?? [];
    final allDeposits = <Deposit>[];
    for (final raw in rawDeps) {
      try {
        allDeposits.add(Deposit.fromJson(raw as Map<String, dynamic>));
      } catch (_) {}
    }

    // My deposits (depositedBy == myUid) — fallback: all if none tagged
    final myDeposits = allDeposits.where((d) => d.depositedBy == myUid).toList();
    final partnerDeposits =
        allDeposits.where((d) => d.depositedBy == _partnerUid).toList();

    // If no deposits are tagged (old data), split equally by index
    final List<Deposit> myFinalDeposits;
    final List<Deposit> partnerFinalDeposits;
    if (myDeposits.isEmpty && partnerDeposits.isEmpty && allDeposits.isNotEmpty) {
      final half = (allDeposits.length / 2).ceil();
      myFinalDeposits = allDeposits.sublist(0, half);
      partnerFinalDeposits = allDeposits.sublist(half);
    } else {
      myFinalDeposits = myDeposits;
      partnerFinalDeposits = partnerDeposits;
    }

    // ── 3. Recalculate individual streaks ────────────────────────────────────
    final myStreak = _calculateStreakForDeposits(myFinalDeposits);
    final partnerStreak = _calculateStreakForDeposits(partnerFinalDeposits);

    // ── 4. Unique deposit days (completedDays) ───────────────────────────────
    Set<String> uniqueDayKeys(List<Deposit> deps) {
      final seen = <String>{};
      for (final d in deps) {
        seen.add('${d.dateOnly.year}-${d.dateOnly.month}-${d.dateOnly.day}');
      }
      return seen;
    }

    final myDays = uniqueDayKeys(myFinalDeposits).length.clamp(0, 100);
    final partnerDays = uniqueDayKeys(partnerFinalDeposits).length.clamp(0, 100);

    // ── 5. Last deposit date ─────────────────────────────────────────────────
    DateTime? lastDate(List<Deposit> deps) {
      if (deps.isEmpty) return null;
      final sorted = [...deps]..sort((a, b) => a.date.compareTo(b.date));
      return sorted.last.dateOnly;
    }

    final myLastDate = lastDate(myFinalDeposits);
    final partnerLastDate = lastDate(partnerFinalDeposits);

    // ── 6. Split coins & lifebuoys 50/50 ────────────────────────────────────
    final totalCoins = sessionData['woodenCoins'] as int? ?? _woodenCoins;
    final totalLifebuoys = sessionData['lifebuoys'] as int? ?? _lifebuoys;
    final halfCoins = totalCoins ~/ 2;
    final halfLifebuoys = totalLifebuoys ~/ 2;
    // Approver gets the odd remainder
    final myCoins = halfCoins + (totalCoins % 2);
    final myLifebuoys = halfLifebuoys + (totalLifebuoys % 2);
    final partnerCoins = halfCoins;
    final partnerLifebuoys = halfLifebuoys;

    // ── 7. Write MY OWN user document back to فردي (only MY document!) ───────
    // We store partner's split data inside the session document so that
    // the partner's device can read it on next app start and apply it.
    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .set({
      'user_profile_v1': {
        'challengeType': 'فردي',
        'fullName': _userProfile != null ? _cleanName(_userProfile!.fullName) : 'مستخدم',
      },
      _kDeposits: myFinalDeposits.map((d) => d.toJson()).toList(),
      'current_streak_v1': myStreak,
      'lifebuoys_v1': myLifebuoys,
      'wooden_coins_v1': myCoins,
      'completed_days_count': myDays,
      'is_complete_v1': myDays >= 100,
      'last_deposit_date_v1':
          myLastDate != null ? myLastDate.toIso8601String() : FieldValue.delete(),
      'activeSessionId': FieldValue.delete(),
      'cooperativePartnerUid': FieldValue.delete(),
      'cooperativePartnerName': FieldValue.delete(),
      'cooperativePartnerAvatarIndex': FieldValue.delete(),
    }, SetOptions(merge: true));

    // Dissolve any accepted invitations so that Challenge Hub returns to normal
    await ChallengeService.dissolveChallengeInvitations(myUid, _partnerUid!);

    // ── 8. Mark session as dissolved & embed partner's split data ────────────
    // Embedding the partner's data lets their device apply it on next start
    // without needing cross-user write permissions.
    await FirebaseFirestore.instance
        .collection(sessionCollection)
        .doc(_activeSessionId!)
        .update({
      'status': 'dissolved',
      'dissolvedAt': FieldValue.serverTimestamp(),
      'separationRequest': FieldValue.delete(),
      'partnerSplit': {
        'uid': _partnerUid,
        'deposits': partnerFinalDeposits.map((d) => d.toJson()).toList(),
        'streak': partnerStreak,
        'lifebuoys': partnerLifebuoys,
        'woodenCoins': partnerCoins,
        'completedDays': partnerDays,
        'lastDepositDate': partnerLastDate?.toIso8601String(),
      },
    });
  }

  Future<void> _persist({Deposit? newDeposit}) async {
    if (isCooperativeMode) {
      await _persistCooperative(newDeposit: newDeposit);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    if (isComplete && _completedAt == null) {
      _completedAt = _lastDepositDate ?? DateTime.now();
    } else if (!isComplete) {
      _completedAt = null;
    }

    // ── إنشاء نسخة الملف الشخصي مع حقول البحث ──────────────────────────────
    Map<String, dynamic>? profileData;
    if (_userProfile != null) {
      profileData = _userProfile!.toJson();
      // حقول lowercase للبحث الفعّال server-side
      profileData['fullName_lower'] =
          (_userProfile!.fullName).toLowerCase().trim();
      profileData['contact_lower'] =
          (_userProfile!.contact).toLowerCase().trim();
    }

    final updateData = <String, dynamic>{
      _kUserProfile: profileData ?? FieldValue.delete(),
      _kDeposits: _deposits.map((d) => d.toJson()).toList(),
      'current_streak_v1': _currentStreak,
      'lifebuoys_v1': _lifebuoys,
      'lifebuoys_used_v1': _lifebuoysUsed,
      'last_deposit_date_v1': _lastDepositDate?.toIso8601String() ?? FieldValue.delete(),
      'wooden_coins_v1': _woodenCoins,
      'last_daily_claim_v1': _lastDailyClaimDate ?? FieldValue.delete(),
      'ads_watched_v1': _adsWatchedToday,
      'shares_done_v1': _sharesDoneToday,
      'current_date_str_v1': _currentDateStr ?? FieldValue.delete(),
      'avatarIndex': _avatarIndex,
      // ─ حقل لتمكين الفرز في لوحة الصدارة من طرف الخادم مباشرة ─
      'completed_days_count': completedDays,
      // ─ علامة الإتمام لتبويب نادي المئة ─
      'is_complete_v1': isComplete,
      'completedAt': _completedAt != null ? Timestamp.fromDate(_completedAt!) : FieldValue.delete(),
    };

    await docRef.set(updateData, SetOptions(merge: true));
  }

  // ── Poke (نكز) Feature ───────────────────────────────────────

  bool get canPokeToday => _lastPokeDate != _todayStr();

  /// يرسل نكزة للخصم (تكلف 10 مسكوكات). Throws:
  /// - 'insufficient_coins' إذا كان الرصيد أقل من 10
  /// - 'already_poked_today' إذا نكز المستخدم اليوم بالفعل
  Future<void> pokePartner() async {
    if (_woodenCoins < 10) throw Exception('insufficient_coins');
    if (!canPokeToday) throw Exception('already_poked_today');
    if (_activeSessionId == null || _partnerUid == null) throw Exception('no_active_session');

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final today = _todayStr();
    final myName = _userProfile?.fullName ?? 'مستخدم';

    // خصم 10 مسكوكات
    _woodenCoins -= 10;
    _lastPokeDate = today;

    // كتابة طلب النكزة في وثيقة الجلسة التنافسية بمفتاح مخصص للخصم لمنع التداخل
    await FirebaseFirestore.instance
        .collection('competitive_sessions')
        .doc(_activeSessionId!)
        .set({
      'poke_to_$_partnerUid': {
        'fromUid': myUid,
        'fromName': myName,
        'date': today,
        'sentAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    // حفظ الرصيد الجديد في Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .update({'wooden_coins_v1': _woodenCoins}).catchError((_) {});

    notifyListeners();
    await _logActivity(
      type: ActivityType.pokePartner,
      title: 'إرسال نكزة',
      description: 'تم إرسال نكزة للخصم بقيمة 10 عملات',
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    await init();
  }
  Future<void> updateAccountDetails({
    String? fullName,
    String? bio,
    String? newEmail,
    String? newPassword,
    String? maritalStatus,
    DateTime? birthDate,
    String? goal,
    double? financialGoal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userProfile == null) throw Exception('User not logged in');

    // 1. Update Firebase Auth if needed
    if (newEmail != null && newEmail.isNotEmpty && newEmail != user.email) {
      await user.verifyBeforeUpdateEmail(newEmail);
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      await user.updatePassword(newPassword);
    }

    // 2. Update Firestore document
    final updatedFullName = (fullName != null && fullName.trim().isNotEmpty) ? fullName.trim() : _userProfile!.fullName;
    final updatedBio = bio ?? _userProfile!.bio;
    final updatedMaritalStatus = maritalStatus ?? _userProfile!.maritalStatus;
    final updatedBirthDate = birthDate ?? _userProfile!.birthDate;
    final updatedGoal = goal ?? _userProfile!.goal;
    final updatedFinancialGoal = financialGoal ?? _userProfile!.financialGoal;
    
    // We must ensure 'contact' is updated if email was changed
    final updatedContact = (newEmail != null && newEmail.isNotEmpty) ? newEmail : _userProfile!.contact;

    // 2. Update local state
    final oldProfile = _userProfile!;
    _userProfile = UserProfile(
      fullName: updatedFullName,
      gender: _userProfile!.gender,
      contact: updatedContact,
      financialGoal: updatedFinancialGoal,
      maritalStatus: updatedMaritalStatus,
      goal: updatedGoal,
      challengeType: _userProfile!.challengeType,
      birthDate: updatedBirthDate,
      bio: updatedBio,
    );
    notifyListeners();
    
    // 3. Persist to Firestore
    await _persist();
    
    // Check what changed and log it
    final changesOld = <String>[];
    final changesNew = <String>[];
    
    if (oldProfile.fullName != updatedFullName) {
      changesOld.add('الاسم: ${oldProfile.fullName}');
      changesNew.add('الاسم: $updatedFullName');
    }
    if (oldProfile.bio != updatedBio) {
      changesOld.add('النبذة: ${oldProfile.bio}');
      changesNew.add('النبذة: $updatedBio');
    }
    if (oldProfile.contact != updatedContact) {
      changesOld.add('الإيميل: ${oldProfile.contact}');
      changesNew.add('الإيميل: $updatedContact');
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      changesOld.add('الرمز السري: ******');
      changesNew.add('الرمز السري: ******');
    }
    if (oldProfile.financialGoal != updatedFinancialGoal) {
      changesOld.add('الهدف المالي: ${oldProfile.financialGoal.toStringAsFixed(2)} JD');
      changesNew.add('الهدف المالي: ${updatedFinancialGoal.toStringAsFixed(2)} JD');
    }
    if (oldProfile.birthDate != updatedBirthDate) {
      final oldDateStr = oldProfile.birthDate != null ? "${oldProfile.birthDate!.year}-${oldProfile.birthDate!.month.toString().padLeft(2, '0')}-${oldProfile.birthDate!.day.toString().padLeft(2, '0')}" : "غير محدد";
      final newDateStr = updatedBirthDate != null ? "${updatedBirthDate.year}-${updatedBirthDate.month.toString().padLeft(2, '0')}-${updatedBirthDate.day.toString().padLeft(2, '0')}" : "غير محدد";
      changesOld.add('تاريخ الميلاد: $oldDateStr');
      changesNew.add('تاريخ الميلاد: $newDateStr');
    }
    if (oldProfile.maritalStatus != updatedMaritalStatus) {
      changesOld.add('الحالة الاجتماعية: ${oldProfile.maritalStatus}');
      changesNew.add('الحالة الاجتماعية: $updatedMaritalStatus');
    }
    if (oldProfile.goal != updatedGoal) {
      changesOld.add('الهدف الأساسي: ${oldProfile.goal}');
      changesNew.add('الهدف الأساسي: $updatedGoal');
    }

    if (changesOld.isNotEmpty) {
      await _logActivity(
        type: ActivityType.updateProfile,
        title: 'تعديل بيانات الحساب',
        description: 'تم تعديل بيانات الحساب',
        oldValue: changesOld.join('|'),
        newValue: changesNew.join('|'),
      );
    }
    
    // 4. Sync with partner if in cooperative mode
    if (isCooperativeMode && _activeSessionId != null && _partnerUid != null) {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('cooperative_sessions').doc(_activeSessionId),
        {'financialGoal': updatedFinancialGoal}
      );
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(_partnerUid),
        {'user_profile_v1.financialGoal': updatedFinancialGoal}
      );
      batch.commit().catchError((_) {});
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String gender,
    required String contact,
    required double financialGoal,
    required String maritalStatus,
    required String goal,
    required String challengeType,
    DateTime? birthDate,
    int avatarIndex = 0,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    }
    
    _userProfile = UserProfile(
      fullName: fullName,
      gender: gender,
      contact: contact,
      financialGoal: financialGoal,
      maritalStatus: maritalStatus,
      goal: goal,
      challengeType: challengeType,
      birthDate: birthDate,
    );
    _avatarIndex = avatarIndex;
    _deposits.clear();
    _currentStreak = 0;
    _lifebuoys = 0;
    _lastDepositDate = null;
    _woodenCoins = 0;
    _lastDailyClaimDate = null;
    _adsWatchedToday = 0;
    _sharesDoneToday = 0;
    _currentDateStr = null;
    _completedAt = null;
    notifyListeners();
    await _persist();
    await init();
  }

  Future<void> signInWithGoogle() async {
    // Google Sign-In سيتم تفعيله لاحقاً بعد إعداد SHA-1 وتحديث google-services.json
    throw Exception('تسجيل الدخول بـ Google غير متاح حالياً. الرجاء استخدام الإيميل.');
  }

  /// Log a new deposit. Can be called multiple times per day.
  Future<void> logDeposit({
    required double amount,
    String? notes,
  }) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // ─── حماية من التلاعب بالوقت (النهج الهجين) ───────────────────────────────
    // 1. التحقق الخلفي (أوفلاين/أونلاين): منع التراجع بالزمن
    if (_lastDepositDate != null && todayOnly.isBefore(_lastDepositDate!)) {
      throw Exception('لا يمكن تسجيل إيداع بتاريخ يسبق تاريخ آخر إيداع مسجل!');
    }

    // 2. التحقق الأمامي (أونلاين): منع تقديم التاريخ المحلي عن وقت الشبكة
    final networkTime = await _getNetworkTime();
    if (networkTime != null) {
      final networkLocal = networkTime.toLocal();
      final networkOnly = DateTime(networkLocal.year, networkLocal.month, networkLocal.day);
      if (todayOnly.isAfter(networkOnly)) {
        throw Exception('تنبيه: تم الكشف عن تلاعب بالوقت! وقت هاتفك متقدم عن الوقت الحقيقي. يرجى ضبط وقت الهاتف على الوضع التلقائي.');
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    final deposit = Deposit(
      amount: amount,
      date: today,
      notes: notes,
      depositedBy: isCooperativeMode ? uid : null,
    );
    _deposits.add(deposit);

    _updateStreakAndLastDate();

    notifyListeners();
    await _persist(newDeposit: deposit);

    await _logActivity(
      type: ActivityType.deposit,
      title: 'إيداع جديد',
      description: 'تم إيداع مبلغ ${amount.toStringAsFixed(2)} JD${notes != null && notes.isNotEmpty ? ' - $notes' : ''}',
    );

    // ─ حماية من التلاعب بالوقت: حفظ Server Timestamp في Firestore ─
    // يُستخدم هذا الحقل للتحقق المستقبلي من صحة التواريخ
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'last_deposit_server_ts': FieldValue.serverTimestamp()}, SetOptions(merge: true))
          .catchError((_) {}); // لا نوقف العملية إذا فشل الطلب
    }
  }

  Future<DateTime?> _getNetworkTime() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.headUrl(Uri.parse('https://www.google.com'));
      final response = await request.close();
      final dateHeader = response.headers.value(HttpHeaders.dateHeader);
      if (dateHeader != null) {
        return HttpDate.parse(dateHeader);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching network time: $e');
      }
    }
    return null;
  }

  Future<void> updateDeposit(String id, {required double amount, String? notes}) async {
    final index = _deposits.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final oldDeposit = _deposits[index];
    _deposits[index] = Deposit(
      id: oldDeposit.id,
      amount: amount,
      date: oldDeposit.date,
      notes: notes,
    );
    notifyListeners();
    await _persist();

    final changesOld = <String>[];
    final changesNew = <String>[];

    if (oldDeposit.amount != amount) {
      changesOld.add('المبلغ: ${oldDeposit.amount.toStringAsFixed(2)} JD');
      changesNew.add('المبلغ: ${amount.toStringAsFixed(2)} JD');
    }
    
    final oldNotes = oldDeposit.notes ?? '';
    final newNotes = notes ?? '';
    if (oldNotes != newNotes) {
      changesOld.add('الملاحظات: ${oldNotes.isEmpty ? "لا يوجد" : oldNotes}');
      changesNew.add('الملاحظات: ${newNotes.isEmpty ? "لا يوجد" : newNotes}');
    }

    if (changesOld.isNotEmpty) {
      await _logActivity(
        type: ActivityType.updateDeposit,
        title: 'تعديل الإيداع',
        description: 'تم تعديل تفاصيل الإيداع',
        oldValue: changesOld.join('|'),
        newValue: changesNew.join('|'),
      );
    }
  }

  Future<void> deleteDeposit(String id) async {
    final depIndex = _deposits.indexWhere((d) => d.id == id);
    String amountText = '';
    if (depIndex != -1) {
      final amt = _deposits[depIndex].amount;
      amountText = ' بقيمة ${amt.toStringAsFixed(amt.truncateToDouble() == amt ? 0 : 2)} د.أ';
      _deposits.removeAt(depIndex);
    } else {
      _deposits.removeWhere((d) => d.id == id);
    }
    _updateStreakAndLastDate();
    notifyListeners();
    await _persist();
    await _logActivity(
      type: ActivityType.deleteDeposit,
      title: 'حذف إيداع',
      description: 'تم حذف إيداع$amountText',
    );
  }

  Future<void> useLifebuoy() async {
    final cost = lifebuoyCost;
    if (cost == 0) return;          // لا حاجة للطوق أو الستريك منتهٍ
    if (_lifebuoys < cost) return;  // أطواق غير كافية
    _lifebuoys -= cost;
    _lifebuoysUsed += cost;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // إضافة إيداعات وهمية لتسجيل الأيام التي تمت حمايتها بطوق النجاة
    final gap = daysSinceLastDeposit;
    if (gap >= 2) {
      final savedDate1 = todayOnly.subtract(const Duration(days: 1));
      _deposits.add(Deposit(
        amount: 0.0,
        date: savedDate1,
        notes: 'lifebuoy',
      ));
      if (gap == 3) {
        final savedDate2 = todayOnly.subtract(const Duration(days: 2));
        _deposits.add(Deposit(
          amount: 0.0,
          date: savedDate2,
          notes: 'lifebuoy',
        ));
      }
    }

    _updateStreakAndLastDate();
    notifyListeners();
    await _persist();
    await _logActivity(
      type: ActivityType.useLifebuoy,
      title: 'استخدام طوق النجاة',
      description: 'تم استخدام $cost طوق نجاة لإنقاذ السلسلة من الكسر',
    );
  }

  Future<void> resetStreak() async {
    _currentStreak = 0;
    notifyListeners();
    await _persist();
  }

  // ── Coins & Rewards Logic ───────────────────────────────────────────────────

  void checkAndResetDailyCounters() {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    if (_currentDateStr != todayStr) {
      _currentDateStr = todayStr;
      _adsWatchedToday = 0;
      _sharesDoneToday = 0;
      _persist();
    }
  }

  Future<void> addCoins(int amount) async {
    _woodenCoins += amount;
    notifyListeners();
    await _persist();
  }

  Future<void> updateFinancialGoal(double goal) async {
    if (_userProfile != null) {
      final oldGoal = _userProfile!.financialGoal;
      if (oldGoal == goal) return; // No change

      _userProfile!.financialGoal = goal;
      notifyListeners();
      await _persist();
      
      // Sync goal with partner if in cooperative mode
      if (isCooperativeMode && _activeSessionId != null && _partnerUid != null) {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('cooperative_sessions').doc(_activeSessionId),
          {'financialGoal': goal}
        );
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(_partnerUid),
          {'user_profile_v1.financialGoal': goal}
        );
        batch.commit().catchError((_) {});
      }
      
      await _logActivity(
        type: ActivityType.updateGoal,
        title: 'تحديث الهدف المالي',
        description: 'تم تحديث الهدف المالي',
        oldValue: '${oldGoal.toStringAsFixed(2)} JD',
        newValue: '${goal.toStringAsFixed(2)} JD',
      );
    }
  }

  Future<bool> deductCoins(int amount) async {
    if (_woodenCoins >= amount) {
      _woodenCoins -= amount;
      notifyListeners();
      await _persist();
      return true;
    }
    return false;
  }

  Future<void> claimDailyReward() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_lastDailyClaimDate == todayStr) return;

    _woodenCoins += 10;
    _lastDailyClaimDate = todayStr;
    notifyListeners();
    await _persist();
    await _logActivity(
      type: ActivityType.claimCoins,
      title: 'المكافأة اليومية',
      description: 'حصلت على 10 عملات خشبية',
    );
  }

  Future<void> watchAdReward() async {
    checkAndResetDailyCounters();
    if (_adsWatchedToday >= 4) return;
    
    _woodenCoins += 25;
    _adsWatchedToday += 1;
    notifyListeners();
    await _persist();
    await _logActivity(
      type: ActivityType.watchAd,
      title: 'مشاهدة إعلان',
      description: 'حصلت على 25 عملة خشبية',
    );
  }

  Future<bool> registerShareReward() async {
    checkAndResetDailyCounters();
    if (_sharesDoneToday >= 5) return false;
    
    _woodenCoins += 20;
    _sharesDoneToday += 1;
    notifyListeners();
    await _persist();
    await _logActivity(
      type: ActivityType.claimCoins,
      title: 'مشاركة التطبيق',
      description: 'حصلت على 20 عملة خشبية',
    );
    return true;
  }

  Future<void> buyLifebuoy() async {
    if (await deductCoins(1000)) {
      _lifebuoys += 1;
      notifyListeners();
      await _persist();
      await _logActivity(
        type: ActivityType.buyLifebuoy,
        title: 'شراء طوق نجاة',
        description: 'تم شراء طوق نجاة مقابل 1000 عملة',
      );
    } else {
      throw Exception('ليس لديك عملات كافية!');
    }
  }

  Future<void> updateAvatarIndex(int index) async {
    _avatarIndex = index;
    notifyListeners();
    await _persist();
    
    // Sync with partner if in a challenge session
    if (_activeSessionId != null && _partnerUid != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection(_activeSessionCollection).doc(_activeSessionId),
          {'userAvatars.$uid': index}
        );
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(_partnerUid),
          {'cooperativePartnerAvatarIndex': index}
        );
        batch.commit().catchError((_) {});
      }
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final oldProfile = _userProfile;
    _userProfile = profile;
    notifyListeners();
    await _persist();

    // Sync name with partner if in a challenge session
    if (_activeSessionId != null && _partnerUid != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection(_activeSessionCollection).doc(_activeSessionId),
          {'userNames.$uid': profile.fullName}
        );
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(_partnerUid),
          {'cooperativePartnerName': profile.fullName}
        );
        batch.commit().catchError((_) {});
      }
    }

    if (oldProfile != null) {
      final changesOld = <String>[];
      final changesNew = <String>[];

      if (oldProfile.fullName != profile.fullName) {
        changesOld.add('الاسم: ${oldProfile.fullName}');
        changesNew.add('الاسم: ${profile.fullName}');
      }
      if (oldProfile.bio != profile.bio) {
        changesOld.add('النبذة: ${oldProfile.bio}');
        changesNew.add('النبذة: ${profile.bio}');
      }
      if (oldProfile.birthDate != profile.birthDate) {
        final oldDateStr = oldProfile.birthDate != null ? "${oldProfile.birthDate!.year}-${oldProfile.birthDate!.month.toString().padLeft(2, '0')}-${oldProfile.birthDate!.day.toString().padLeft(2, '0')}" : "غير محدد";
        final newDateStr = profile.birthDate != null ? "${profile.birthDate!.year}-${profile.birthDate!.month.toString().padLeft(2, '0')}-${profile.birthDate!.day.toString().padLeft(2, '0')}" : "غير محدد";
        changesOld.add('تاريخ الميلاد: $oldDateStr');
        changesNew.add('تاريخ الميلاد: $newDateStr');
      }
      if (oldProfile.maritalStatus != profile.maritalStatus) {
        changesOld.add('الحالة الاجتماعية: ${oldProfile.maritalStatus}');
        changesNew.add('الحالة الاجتماعية: ${profile.maritalStatus}');
      }
      if (oldProfile.goal != profile.goal) {
        changesOld.add('الهدف الأساسي: ${oldProfile.goal}');
        changesNew.add('الهدف الأساسي: ${profile.goal}');
      }
      if (oldProfile.challengeType != profile.challengeType) {
        changesOld.add('نوع التحدي: ${oldProfile.challengeType}');
        changesNew.add('نوع التحدي: ${profile.challengeType}');
      }

      if (changesOld.isNotEmpty) {
        await _logActivity(
          type: ActivityType.updateProfile,
          title: 'تعديل الملف الشخصي',
          description: 'تم تعديل بيانات الملف الشخصي',
          oldValue: changesOld.join('|'),
          newValue: changesNew.join('|'),
        );
      }
    }
  }

  Future<void> signOut() async {
    _cancelFriendsListeners();
    _activeSessionSubscription?.cancel();
    _activeSessionSubscription = null;
    _activeSessionId = null;

    _userProfile = null;
    _deposits.clear();
    _currentStreak = 0;
    _lifebuoys = 0;
    _lastDepositDate = null;
    _woodenCoins = 0;
    _lastDailyClaimDate = null;
    _adsWatchedToday = 0;
    _sharesDoneToday = 0;
    _currentDateStr = null;
    _completedAt = null;
    _avatarIndex = 0;
    _hasNewSession = false;
    _newSessionType = null;
    notifyListeners();
    await FirebaseAuth.instance.signOut();
  }

  // ── Debug Helpers ────────────────────────────────────────────────────────

  Future<void> debugSetDays(int days) async {
    _deposits.clear();
    final now = DateTime.now();
    for (int i = 1; i <= days; i++) {
      _deposits.add(Deposit(
        amount: 10.0,
        date: now.subtract(Duration(days: days - i)),
        notes: 'Debug deposit',
      ));
    }
    notifyListeners();
    await _persist();
  }

  Future<void> debugResetData() async {
    _deposits.clear();
    _currentStreak = 0;
    _lifebuoys = 0;
    _lifebuoysUsed = 0;
    _lastDepositDate = null;
    _completedAt = null;
    _avatarIndex = 0;
    notifyListeners();
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_insight_date');
    await prefs.remove('last_quest_date');
    await prefs.remove('quest_accepted_day');
    await prefs.remove('quest_done_day');
    await prefs.remove('last_milestone_shown');
  }

  Future<void> debugAddLifebuoy() async {
    _lifebuoys++;
    notifyListeners();
    await _persist();
  }

  Future<void> debugAdd500Coins() async {
    _woodenCoins += 500;
    notifyListeners();
    await _persist();
  }

  Future<void> debugResetDailyLimits() async {
    _adsWatchedToday = 0;
    _sharesDoneToday = 0;
    _lastDailyClaimDate = null;
    notifyListeners();
    await _persist();
  }

  void _startFriendsListeners(String myUid) {
    _incomingRequestsSubscription?.cancel();
    _acceptedRequestsSubscription?.cancel();
    _challengeInvitationsSubscription?.cancel();
    _cooperativeSessionsListener?.cancel();
    _competitiveSessionsListener?.cancel();

    // 0. Listen for new active cooperative sessions
    _cooperativeSessionsListener = FirebaseFirestore.instance
        .collection('cooperative_sessions')
        .where('users', arrayContains: myUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // If a new session appeared and we are not in challenge mode yet
          if (!isCooperativeMode && !isCompetitiveMode) {
            _hasNewSession = true;
            _newSessionType = 'تعاوني';
            notifyListeners();
          }
        }
      }
    });

    // 0.1 Listen for new active competitive sessions
    _competitiveSessionsListener = FirebaseFirestore.instance
        .collection('competitive_sessions')
        .where('users', arrayContains: myUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // If a new session appeared and we are not in challenge mode yet
          if (!isCooperativeMode && !isCompetitiveMode) {
            _hasNewSession = true;
            _newSessionType = 'تنافسي';
            notifyListeners();
          }
        }
      }
    });

    // 1. Listen for new pending incoming requests
    _incomingRequestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final senderName = data['fromName'] as String? ?? 'صديق';
          final createdAt = data['createdAt'] as Timestamp?;
          // Only show notification for requests created AFTER the app started
          if (createdAt != null && createdAt.toDate().isAfter(_appStartTime)) {
            await NotificationService().showInstantNotification(
              'طلب صداقة جديد! 👋',
              'أرسل لك $senderName طلب صداقة.',
            );
          }
        }
      }
    });

    // 2. Listen for accepted requests
    _acceptedRequestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }
        final data = change.doc.data();
        if (data == null) continue;

        // ── Guard: only notify for acceptances that happened AFTER app start ──
        final acceptedAt = data['updatedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;
        if (acceptedAt == null || !acceptedAt.toDate().isAfter(_appStartTime)) continue;

        final toUid = data['toUid'] as String?;
        if (toUid == null) continue;

        final reqId = change.doc.id;
        if (_notifiedAcceptedRequestIds.contains(reqId)) continue;
        _notifiedAcceptedRequestIds.add(reqId);

        // Fetch receiver's name
        final userSnap = await FirebaseFirestore.instance.collection('users').doc(toUid).get();
        String receiverName = 'صديق';
        if (userSnap.exists) {
          final profile = userSnap.data()?['user_profile_v1'] as Map<String, dynamic>? ?? {};
          receiverName = profile['fullName'] as String? ?? 'صديق';
        }

        // Trigger local notification
        await NotificationService().showInstantNotification(
          'تم قبول طلب الصداقة! 🎉',
          'قبل $receiverName طلب الصداقة الخاص بك.',
        );
      }
    });

    // 3. Listen for incoming challenge invitations
    _challengeInvitationsSubscription = FirebaseFirestore.instance
        .collection('challenge_invitations')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final createdAt = data['createdAt'] as Timestamp?;
          // Only show notification for invitations created AFTER the app started
          if (createdAt != null && createdAt.toDate().isAfter(_appStartTime)) {
            final senderName = data['senderName'] as String? ?? 'مستخدم';
            final typeStr = data['type'] as String? ?? 'cooperative';
            final typeLabel = typeStr == 'cooperative' ? 'تعاوني' : 'تنافسي';
            await NotificationService().showInstantNotification(
              'دعوة تحدي $typeLabel! ⚔️',
              'أرسل لك $senderName دعوة للانضمام إلى تحدي $typeLabel.',
            );
          }
        }
      }
    });
  }

  void _cancelFriendsListeners() {
    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = null;
    _acceptedRequestsSubscription?.cancel();
    _acceptedRequestsSubscription = null;
    _challengeInvitationsSubscription?.cancel();
    _challengeInvitationsSubscription = null;
    _cooperativeSessionsListener?.cancel();
    _cooperativeSessionsListener = null;
    _challengeInvitationsSubscription = null;
    _notifiedAcceptedRequestIds.clear();
  }

  Future<void> _logActivity({
    required ActivityType type,
    required String title,
    required String description,
    String? oldValue,
    String? newValue,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activities')
          .doc();
          
      final log = ActivityLog(
        id: docRef.id,
        uid: uid,
        type: type,
        title: title,
        description: description,
        timestamp: DateTime.now(),
        oldValue: oldValue,
        newValue: newValue,
      );
      
      await docRef.set(log.toMap());
    } catch (e) {
      debugPrint('Failed to log activity: $e');
    }
  }
}
