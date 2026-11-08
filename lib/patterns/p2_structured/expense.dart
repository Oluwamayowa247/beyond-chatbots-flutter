/// The typed model the form is built on. Gemini's JSON parses straight into it.
class Expense {
  const Expense({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
  });

  final String merchant;
  final num amount;
  final String date;
  final String category;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    merchant: (json['merchant'] as String?)?.trim() ?? '',
    amount: (json['amount'] as num?) ?? 0,
    date: (json['date'] as String?)?.trim() ?? '',
    category: (json['category'] as String?) ?? 'other',
  );

  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'amount': amount,
    'date': date,
    'category': category,
  };
}

const expenseCategories = ['food', 'transport', 'bills', 'other'];
