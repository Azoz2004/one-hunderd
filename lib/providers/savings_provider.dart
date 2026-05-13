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
  int get currentStreak {
    if (_deposits.isEmpty) return 0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final dateSet = <DateTime>{};
    for (final d in _deposits) {
      dateSet.add(d.dateOnly);
    }

    // Start from today; if no deposit today, try yesterday
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
    _deposits.add(Deposit(
      amount: amount,
      date: DateTime.now(),
      notes: notes,
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> signOut() async {
    _userProfile = null;
    _deposits.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserProfile);
    await prefs.remove(_kDeposits);
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
    notifyListeners();
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_insight_date');
    await prefs.remove('last_quest_date');
    await prefs.remove('quest_accepted_day');
    await prefs.remove('quest_done_day');
    await prefs.remove('last_milestone_shown');
  }
}
