import 'dart:math';

/// Represents a single savings deposit transaction.
class Deposit {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;

  Deposit({
    String? id,
    required this.amount,
    required this.date,
    this.notes,
  }) : id = id ?? '${date.millisecondsSinceEpoch}_${Random().nextInt(10000)}';

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  /// Returns just the date portion (midnight) for day-level comparisons.
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);
}
