import 'mock_transaction_service.dart';

/// Generates coach-style insights from local data. Replace with AI insights later.
class InsightService {
  InsightService(this._transactionService);

  final MockTransactionService _transactionService;

  /// Monthly insight text for the "Generate Monthly Insight" dialog.
  String getMonthlyInsight(String currency) {
    final total = _transactionService.currentMonthTotal;
    final yearly = _transactionService.yearlyProjection;
    return '💧 This month you spent ${total.toStringAsFixed(0)} $currency.\n'
        'If repeated yearly → ${yearly.toStringAsFixed(0)} $currency.';
  }

  /// Coach-style response after adding a transaction (used by chat).
  String buildCoachResponse({
    required double amount,
    required String category,
    String? merchant,
    required String currency,
    required double categoryTotalThisMonth,
  }) {
    final subject = merchant ?? category;
    final categoryLine = categoryTotalThisMonth > 0
        ? "You've spent ${categoryTotalThisMonth.toStringAsFixed(0)} $currency on $category this month."
        : "First $category expense this month.";
    return '☕ Added ${amount.toStringAsFixed(0)} $currency to $subject.\n$categoryLine';
  }
}
