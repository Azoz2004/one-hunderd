/// Represents a single savings deposit transaction.
class Deposit {
  final double amount;
  final DateTime date;
  final String? notes;

  Deposit({required this.amount, required this.date, this.notes});

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  /// Returns just the date portion (midnight) for day-level comparisons.
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);
}
