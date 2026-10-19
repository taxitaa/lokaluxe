class ExpenseModel {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final String date;
  final bool isIncome;

  ExpenseModel({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.isIncome = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date,
      'isIncome': isIncome ? 1 : 0,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] ?? '',
      isIncome: (map['isIncome'] == 1 || map['isIncome'] == true),
    );
  }
}
