import '../models/salary_config_model.dart';
import '../models/transaction_model.dart'; // kCategoryGroupNeeds, etc.

/// Result of monthly evaluation. Rule-based; replace with AI scoring later.
class MonthEvaluationResult {
  final double targetNeeds;
  final double targetWants;
  final double targetSavings;
  final double actualNeeds;
  final double actualWants;
  final double actualSavings;
  final double deviationNeeds;
  final double deviationWants;
  final double deviationSavings;
  final double performanceScore;

  const MonthEvaluationResult({
    required this.targetNeeds,
    required this.targetWants,
    required this.targetSavings,
    required this.actualNeeds,
    required this.actualWants,
    required this.actualSavings,
    required this.deviationNeeds,
    required this.deviationWants,
    required this.deviationSavings,
    required this.performanceScore,
  });
}

/// Pure rule-based financial rules. No AI. Injectable; replace with AI rule engine later.
class FinancialRulesService {
  /// Default 50/30/20 allocation. Replace with personalized rules when using AI.
  static const AllocationPercentages defaultAllocation = AllocationPercentages(
    needs: 50,
    wants: 30,
    savings: 20,
  );

  /// Calculate target amounts from income and allocation. Pure function.
  ({double targetNeeds, double targetWants, double targetSavings}) calculateTargets(
    double income,
    AllocationPercentages allocation,
  ) {
    return (
      targetNeeds: income * (allocation.needs / 100),
      targetWants: income * (allocation.wants / 100),
      targetSavings: income * (allocation.savings / 100),
    );
  }

  /// Compare actual spending (by group) to targets. Returns deviations and simple % match score.
  MonthEvaluationResult evaluateMonth(
    double income,
    AllocationPercentages allocation,
    Map<String, double> actualByGroup,
  ) {
    final targets = calculateTargets(income, allocation);
    final actualNeeds = actualByGroup[kCategoryGroupNeeds] ?? 0;
    final actualWants = actualByGroup[kCategoryGroupWants] ?? 0;
    final actualSavings = actualByGroup[kCategoryGroupSavings] ?? 0;

    final deviationNeeds = actualNeeds - targets.targetNeeds;
    final deviationWants = actualWants - targets.targetWants;
    final deviationSavings = actualSavings - targets.targetSavings;

    // Simple performance: how close each bucket is to target (0–100% match per bucket, then average).
    double scoreNeeds = 1.0;
    if (targets.targetNeeds > 0) {
      final ratio = actualNeeds / targets.targetNeeds;
      scoreNeeds = ratio <= 1 ? ratio : (2 - ratio).clamp(0.0, 1.0);
    }
    double scoreWants = 1.0;
    if (targets.targetWants > 0) {
      final ratio = actualWants / targets.targetWants;
      scoreWants = ratio <= 1 ? ratio : (2 - ratio).clamp(0.0, 1.0);
    }
    double scoreSavings = 1.0;
    if (targets.targetSavings > 0) {
      final ratio = actualSavings / targets.targetSavings;
      scoreSavings = ratio >= 1 ? 1.0 : ratio;
    }
    final performanceScore = ((scoreNeeds + scoreWants + scoreSavings) / 3) * 100;

    return MonthEvaluationResult(
      targetNeeds: targets.targetNeeds,
      targetWants: targets.targetWants,
      targetSavings: targets.targetSavings,
      actualNeeds: actualNeeds,
      actualWants: actualWants,
      actualSavings: actualSavings,
      deviationNeeds: deviationNeeds,
      deviationWants: deviationWants,
      deviationSavings: deviationSavings,
      performanceScore: performanceScore,
    );
  }

  /// Generate rule-based insight from evaluation. No LLM.
  String insightFromEvaluation(MonthEvaluationResult e, String currency) {
    final parts = <String>[];
    if (e.actualSavings < e.targetSavings && e.targetSavings > 0) {
      parts.add('You saved less than your target this month.');
    }
    if (e.actualWants > e.targetWants && e.targetWants > 0) {
      parts.add('Wants exceeded recommended allocation.');
    }
    if (e.deviationNeeds > 0 && e.targetNeeds > 0) {
      parts.add('Needs spending was over target.');
    }
    if (parts.isEmpty || e.performanceScore >= 80) {
      return 'You stayed close to your plan.';
    }
    return parts.join(' ');
  }
}
