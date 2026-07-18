import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  deposit,
  updateDeposit,
  deleteDeposit,
  claimCoins,
  watchAd,
  useLifebuoy,
  buyLifebuoy,
  updateGoal,
  addPartner,
  separatePartner,
  pokePartner,
  updateProfile,
  signUp,
  unknown
}

class ActivityLog {
  final String id;
  final String uid;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? oldValue;
  final String? newValue;

  ActivityLog({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.oldValue,
    this.newValue,
  });

  factory ActivityLog.fromMap(String id, Map<String, dynamic> map) {
    return ActivityLog(
      id: id,
      uid: map['uid'] as String? ?? '',
      type: _typeFromString(map['type'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      oldValue: map['oldValue'] as String?,
      newValue: map['newValue'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'type': type.name,
      'title': title,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      if (oldValue != null) 'oldValue': oldValue,
      if (newValue != null) 'newValue': newValue,
    };
  }

  static ActivityType _typeFromString(String? value) {
    if (value == null) return ActivityType.unknown;
    return ActivityType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityType.unknown,
    );
  }
}
