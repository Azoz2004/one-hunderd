import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deposit.dart';
import '../models/user_profile.dart';

// ─── SharedPrefs keys ─────────────────────────────────────────────────────────
const _kUserProfile = 'user_profile_v1';
const _kDeposits = 'deposits_v1';

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
  DateTime? _lastDepositDate;

  int _woodenCoins = 0;
  String? _lastDailyClaimDate;
  int _adsWatchedToday = 0;
  int _sharesDoneToday = 0;
  String? _currentDateStr;

  // ── Getters ──────────────────────────────────────────────────────────────

  UserProfile? get userProfile => _userProfile;
  bool get isLoggedIn => _userProfile != null;
  List<Deposit> get deposits => List.unmodifiable(_deposits);

  /// All unique calendar dates that have at least one deposit, sorted ascending.
  List<DateTime> get uniqueDepositDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final d in _deposits) {
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
    return _deposits.where((d) => d.dateOnly == targetDate).toList();
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
  DateTime? get lastDepositDate => _lastDepositDate;

  int get woodenCoins => _woodenCoins;
  String? get lastDailyClaimDate => _lastDailyClaimDate;
  int get adsWatchedToday => _adsWatchedToday;
  int get sharesDoneToday => _sharesDoneToday;

  /// Whether the streak is broken (missed more than 1 day)
  bool get isStreakBroken {
    if (_lastDepositDate == null || _currentStreak == 0) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return todayOnly.difference(_lastDepositDate!).inDays > 1;
  }

  int _calculateOldStreak() {
    if (_deposits.isEmpty) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateSet = <DateTime>{};
    for (final d in _deposits) {
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

  /// Whether the challenge is complete (100 unique days).
  bool get isComplete => completedDays >= 100;

  /// Total amount saved across all deposits.
  double get totalSaved => _deposits.fold(0.0, (sum, d) => sum + d.amount);

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

  /// Loads all persisted data from SharedPreferences.
  /// Call once from main() before runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load user profile
    final profileJson = prefs.getString(_kUserProfile);
    if (profileJson != null) {
      try {
        _userProfile = UserProfile.fromJson(
            jsonDecode(profileJson) as Map<String, dynamic>);
      } catch (_) {
        _userProfile = null;
      }
    }

    // Load streak and lifebuoys
    _currentStreak = prefs.getInt('current_streak_v1') ?? 0;
    _lifebuoys = prefs.getInt('lifebuoys_v1') ?? 0;
    final lastDateStr = prefs.getString('last_deposit_date_v1');
    if (lastDateStr != null) {
      _lastDepositDate = DateTime.tryParse(lastDateStr);
    }

    // Load coins and daily counters
    _woodenCoins = prefs.getInt('wooden_coins_v1') ?? 0;
    _lastDailyClaimDate = prefs.getString('last_daily_claim_v1');
    _adsWatchedToday = prefs.getInt('ads_watched_v1') ?? 0;
    _sharesDoneToday = prefs.getInt('shares_done_v1') ?? 0;
    _currentDateStr = prefs.getString('current_date_str_v1');
    
    checkAndResetDailyCounters();

    // Load deposits
    final depositsJson = prefs.getStringList(_kDeposits) ?? [];
    _deposits.clear();
    for (final raw in depositsJson) {
      try {
        _deposits
            .add(Deposit.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupted entry
      }
    }

    // Migrate old streak logic if needed
    if (prefs.getInt('current_streak_v1') == null && _deposits.isNotEmpty) {
      _currentStreak = _calculateOldStreak();
      _lastDepositDate = uniqueDepositDates.last;
      await _persist();
    }

    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    if (_userProfile != null) {
      await prefs.setString(
          _kUserProfile, jsonEncode(_userProfile!.toJson()));
    } else {
      await prefs.remove(_kUserProfile);
    }

    await prefs.setStringList(
      _kDeposits,
      _deposits.map((d) => jsonEncode(d.toJson())).toList(),
    );

    await prefs.setInt('current_streak_v1', _currentStreak);
    await prefs.setInt('lifebuoys_v1', _lifebuoys);
    if (_lastDepositDate != null) {
      await prefs.setString('last_deposit_date_v1', _lastDepositDate!.toIso8601String());
    } else {
      await prefs.remove('last_deposit_date_v1');
    }

    await prefs.setInt('wooden_coins_v1', _woodenCoins);
    if (_lastDailyClaimDate != null) {
      await prefs.setString('last_daily_claim_v1', _lastDailyClaimDate!);
    } else {
      await prefs.remove('last_daily_claim_v1');
    }
    await prefs.setInt('ads_watched_v1', _adsWatchedToday);
    await prefs.setInt('shares_done_v1', _sharesDoneToday);
    if (_currentDateStr != null) {
      await prefs.setString('current_date_str_v1', _currentDateStr!);
    } else {
      await prefs.remove('current_date_str_v1');
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> signUp({
    required String fullName,
    required String gender,
    required String contact,
    required double financialGoal,
    required String maritalStatus,
    required String goal,
    required String challengeType,
  }) async {
    _userProfile = UserProfile(
      fullName: fullName,
      gender: gender,
      contact: contact,
      financialGoal: financialGoal,
      maritalStatus: maritalStatus,
      goal: goal,
      challengeType: challengeType,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> signInWithGoogle() async {
    _userProfile = UserProfile(
      fullName: 'Ahmad Al-Masri',
      gender: 'Male',
      contact: 'ahmad@gmail.com',
      financialGoal: 5050.0,
      maritalStatus: 'شاب',
      goal: 'بيت',
      challengeType: 'فردي',
    );
    notifyListeners();
    await _persist();
  }

  /// Log a new deposit. Can be called multiple times per day.
  Future<void> logDeposit({
    required double amount,
    String? notes,
  }) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (_lastDepositDate == null) {
      _currentStreak = 1;
    } else {
      final diff = todayOnly.difference(_lastDepositDate!).inDays;
      if (diff == 1) {
        _currentStreak += 1;
      } else if (diff > 1) {
        // Missed days, streak resets to 1 (lifebuoy wasn't used)
        _currentStreak = 1;
      }
      // If diff == 0, it's the same day, streak doesn't increase.
    }
    _lastDepositDate = todayOnly;

    _deposits.add(Deposit(
      amount: amount,
      date: today,
      notes: notes,
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> useLifebuoy() async {
    if (_lifebuoys <= 0) return;
    _lifebuoys -= 1;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    // Fake the last deposit to be yesterday to resume the streak
    _lastDepositDate = todayOnly.subtract(const Duration(days: 1));
    notifyListeners();
    await _persist();
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
  }

  Future<void> watchAdReward() async {
    checkAndResetDailyCounters();
    if (_adsWatchedToday >= 4) return;
    
    _woodenCoins += 25;
    _adsWatchedToday += 1;
    notifyListeners();
    await _persist();
  }

  Future<bool> registerShareReward() async {
    checkAndResetDailyCounters();
    if (_sharesDoneToday >= 5) return false;
    
    _woodenCoins += 20;
    _sharesDoneToday += 1;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> buyLifebuoy() async {
    if (await deductCoins(1000)) {
      _lifebuoys += 1;
      notifyListeners();
      await _persist();
    } else {
      throw Exception('ليس لديك عملات كافية!');
    }
  }

  Future<void> signOut() async {
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserProfile);
    await prefs.remove(_kDeposits);
    await prefs.remove('wooden_coins_v1');
    await prefs.remove('last_daily_claim_v1');
    await prefs.remove('ads_watched_v1');
    await prefs.remove('shares_done_v1');
    await prefs.remove('current_date_str_v1');
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
    _lastDepositDate = null;
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
}
