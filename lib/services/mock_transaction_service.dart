import '../models/transaction_model.dart';

/// In-memory transaction storage. Replace with Supabase/DB later.
class MockTransactionService {
  final List<TransactionModel> _transactions = [];

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  void addTransaction(TransactionModel t) {
    _transactions.add(t);
  }

  /// All transactions in the current month (by createdAt).
  List<TransactionModel> get currentMonthTransactions {
    final now = DateTime.now();
    return _transactions.where((t) {
      return t.createdAt.year == now.year && t.createdAt.month == now.month;
    }).toList();
  }

  /// Total spent this month (legacy; use currentMonthExpenses for expense-only totals).
  double get currentMonthTotal {
    return currentMonthExpenses;
  }

  /// Income total this month (transactions with type income).
  double get currentMonthIncome {
    return currentMonthTransactions
        .where((t) => t.type == kTransactionTypeIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Expenses total this month (transactions with type expense only).
  double get currentMonthExpenses {
    return currentMonthTransactions
        .where((t) => t.type == kTransactionTypeExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Savings total this month.
  double get currentMonthSavings {
    return currentMonthTransactions
        .where((t) => t.type == kTransactionTypeSavings)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Investments total this month.
  double get currentMonthInvestments {
    return currentMonthTransactions
        .where((t) => t.type == kTransactionTypeInvestment)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Net = Income - Expenses - Savings - Investments.
  double get currentMonthNet {
    return currentMonthIncome -
        currentMonthExpenses -
        currentMonthSavings -
        currentMonthInvestments;
  }

  /// Spending by category this month (expenses only). Key = category, value = total.
  Map<String, double> get currentMonthByCategory {
    final map = <String, double>{};
    for (final t in currentMonthTransactions) {
      if (t.type != kTransactionTypeExpense) continue;
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// Spending by category group (needs, wants, savings) this month. Expenses only.
  Map<String, double> get currentMonthByCategoryGroup {
    final map = <String, double>{};
    for (final t in currentMonthTransactions) {
      if (t.type == kTransactionTypeExpense) {
        map[t.categoryGroup] = (map[t.categoryGroup] ?? 0) + t.amount;
      }
    }
    return map;
  }

  /// Top N categories by amount this month.
  List<MapEntry<String, double>> topCategories(int n) {
    final entries = currentMonthByCategory.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).toList();
  }

  /// Yearly projection: current month expenses × 12 (simple mock).
  double get yearlyProjection => currentMonthExpenses * 12;

  /// Clear all. Used by Settings "Reset All Transactions". Replace with backend when needed.
  void clear() {
    _transactions.clear();
  }

  /// Add 20 fake transactions for "Generate Demo Data". Replace with real data/API later.
  void generateDemoData() {
    final now = DateTime.now();
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final demos = [
      _demoTx(baseId + 1, 250, 'Food', 'Coffee', 0, kCategoryGroupNeeds),
      _demoTx(baseId + 2, 450, 'Food', 'Lunch', 1, kCategoryGroupNeeds),
      _demoTx(baseId + 3, 1200, 'Food Delivery', 'Wolt', 2, kCategoryGroupWants),
      _demoTx(baseId + 4, 9.99, 'Subscriptions', 'Netflix', 3, kCategoryGroupWants),
      _demoTx(baseId + 5, 350, 'Food', 'Coffee', 4, kCategoryGroupNeeds),
      _demoTx(baseId + 6, 180, 'Misc', 'Parking', 5, kCategoryGroupWants),
      _demoTx(baseId + 7, 890, 'Food Delivery', 'Wolt', 6, kCategoryGroupWants),
      _demoTx(baseId + 8, 420, 'Food', 'Groceries', 7, kCategoryGroupNeeds),
      _demoTx(baseId + 9, 15, 'Subscriptions', 'iCloud', 8, kCategoryGroupWants),
      _demoTx(baseId + 10, 199, 'Misc', 'Pharmacy', 9, kCategoryGroupWants),
      _demoTx(baseId + 11, 310, 'Food', 'Coffee', 10, kCategoryGroupNeeds),
      _demoTx(baseId + 12, 750, 'Food', 'Dinner', 11, kCategoryGroupNeeds),
      _demoTx(baseId + 13, 1100, 'Food Delivery', 'Wolt', 12, kCategoryGroupWants),
      _demoTx(baseId + 14, 5.99, 'Subscriptions', 'Spotify', 13, kCategoryGroupWants),
      _demoTx(baseId + 15, 280, 'Food', 'Snacks', 14, kCategoryGroupNeeds),
      _demoTx(baseId + 16, 95, 'Misc', 'Transport', 15, kCategoryGroupWants),
      _demoTx(baseId + 17, 1650, 'Food Delivery', 'Wolt', 16, kCategoryGroupWants),
      _demoTx(baseId + 18, 380, 'Food', 'Breakfast', 17, kCategoryGroupNeeds),
      _demoTx(baseId + 19, 12, 'Subscriptions', 'Apple Music', 18, kCategoryGroupWants),
      _demoTx(baseId + 20, 520, 'Misc', 'Shopping', 19, kCategoryGroupWants),
    ];
    for (final t in demos) {
      _transactions.add(t);
    }
  }

  static TransactionModel _demoTx(
    int id,
    double amount,
    String category,
    String merchant,
    int dayIndex,
    String categoryGroup,
  ) {
    final now = DateTime.now();
    final day = (dayIndex % 28) + 1;
    final date = DateTime(now.year, now.month, day.clamp(1, 28));
    return TransactionModel(
      id: 'demo_$id',
      amount: amount,
      category: category,
      merchant: merchant,
      createdAt: date,
      type: kTransactionTypeExpense,
      categoryGroup: categoryGroup,
    );
  }
}
