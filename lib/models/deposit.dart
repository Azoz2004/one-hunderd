import 'dart:math';

/// Represents a single savings deposit transaction.
class Deposit {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? depositedBy; // UID of the user who made this deposit in cooperative mode

  Deposit({
    String? id,
    required this.amount,
    required this.date,
    this.notes,
    this.depositedBy,
  }) : id = id ?? '${date.millisecondsSinceEpoch}_${Random().nextInt(10000)}';

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      depositedBy: json['depositedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'depositedBy': depositedBy,
    };
  }

  /// Returns just the date portion (midnight) for day-level comparisons.
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);
}
