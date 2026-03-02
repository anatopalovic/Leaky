/// Transaction type for allocation (needs/wants/savings). Replace with backend enum later.
typedef TransactionType = String;
const String kTransactionTypeExpense = 'expense';
const String kTransactionTypeIncome = 'income';
const String kTransactionTypeSavings = 'savings';
const String kTransactionTypeInvestment = 'investment';

/// Category group for 50/30/20 rule. Replace with backend when needed.
typedef CategoryGroup = String;
const String kCategoryGroupNeeds = 'needs';
const String kCategoryGroupWants = 'wants';
const String kCategoryGroupSavings = 'savings';

/// Single spending transaction. Replace with Supabase/DB model later.
class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final String? merchant;
  final DateTime createdAt;
  /// expense | income | savings | investment
  final String type;
  /// needs | wants | savings (for allocation tracking)
  final String categoryGroup;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    this.merchant,
    required this.createdAt,
    this.type = kTransactionTypeExpense,
    this.categoryGroup = kCategoryGroupWants,
  });

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? merchant,
    DateTime? createdAt,
    String? type,
    String? categoryGroup,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      categoryGroup: categoryGroup ?? this.categoryGroup,
    );
  }
}
