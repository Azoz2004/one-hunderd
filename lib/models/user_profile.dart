/// Represents a user's profile information.
class UserProfile {
  final String fullName;
  final String gender;
  final String contact; // Email address or Jordanian phone number
  double financialGoal; // Target amount in JD

  /// الحالة الاجتماعية: 'شاب' | 'شابة' | 'متزوج' | 'متزوجة'
  final String maritalStatus;

  /// الهدف: 'زواج' | 'بيت' | 'صحة'
  final String goal;

  /// نوع التحدي: 'فردي' | 'تعاوني' | 'تنافسي'
  final String challengeType;

  /// تاريخ الميلاد
  final DateTime? birthDate;

  UserProfile({
    required this.fullName,
    required this.gender,
    required this.contact,
    this.financialGoal = 5050.0,
    this.maritalStatus = 'شاب',
    this.goal = 'بيت',
    this.challengeType = 'فردي',
    this.birthDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      financialGoal: (json['financialGoal'] as num?)?.toDouble() ?? 5050.0,
      maritalStatus: json['maritalStatus'] as String? ?? 'شاب',
      goal: json['goal'] as String? ?? 'بيت',
      challengeType: json['challengeType'] as String? ?? 'فردي',
      birthDate: json['birthDate'] != null ? DateTime.tryParse(json['birthDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'gender': gender,
      'contact': contact,
      'financialGoal': financialGoal,
      'maritalStatus': maritalStatus,
      'goal': goal,
      'challengeType': challengeType,
      'birthDate': birthDate?.toIso8601String(),
    };
  }
}
