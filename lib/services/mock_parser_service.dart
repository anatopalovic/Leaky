import '../models/transaction_model.dart';

/// Result of parsing user message. Replace with AI parser later.
class ParsedTransaction {
  final double amount;
  final String category;
  final String? merchant;
  /// needs | wants | savings (for allocation)
  final String categoryGroup;

  const ParsedTransaction({
    required this.amount,
    required this.category,
    this.merchant,
    required this.categoryGroup,
  });
}

/// Local parsing only. Replace with AIParserService when integrating AI.
class MockParserService {
  static final RegExp _amountRegex = RegExp(r'[\d]+[.,]?\d*');

  /// Extract amount, category, merchant from raw text (e.g. "Coffee 250", "Wolt 1450").
  ParsedTransaction? parse(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    final amount = _extractAmount(trimmed);
    if (amount == null || amount <= 0) return null;

    final lower = trimmed.toLowerCase();
    String category;
    String? merchant;

    String categoryGroup;
    if (lower.contains('coffee')) {
      category = 'Food';
      merchant = 'Coffee';
      categoryGroup = kCategoryGroupNeeds;
    } else if (lower.contains('wolt')) {
      category = 'Food Delivery';
      merchant = 'Wolt';
      categoryGroup = kCategoryGroupWants;
    } else if (lower.contains('netflix')) {
      category = 'Subscriptions';
      merchant = 'Netflix';
      categoryGroup = kCategoryGroupWants;
    } else {
      category = 'Misc';
      merchant = null;
      categoryGroup = kCategoryGroupWants;
    }

    return ParsedTransaction(
      amount: amount.toDouble(),
      category: category,
      merchant: merchant,
      categoryGroup: categoryGroup,
    );
  }

  double? _extractAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match == null) return null;
    final str = match.group(0)?.replaceAll(',', '.') ?? '';
    return double.tryParse(str);
  }
}
