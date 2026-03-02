/// Allocation percentages for 50/30/20 rule. Replace with backend when needed.
class AllocationPercentages {
  final double needs;
  final double wants;
  final double savings;

  const AllocationPercentages({
    this.needs = 50,
    this.wants = 30,
    this.savings = 20,
  });

  AllocationPercentages copyWith({
    double? needs,
    double? wants,
    double? savings,
  }) {
    return AllocationPercentages(
      needs: needs ?? this.needs,
      wants: wants ?? this.wants,
      savings: savings ?? this.savings,
    );
  }
}

/// Salary configuration (dates, income, allocation). Stored in MockSalaryService.
class SalaryConfig {
  final List<int> salaryDates;
  final double monthlyIncome;
  final AllocationPercentages allocationPercentages;

  const SalaryConfig({
    this.salaryDates = const [],
    this.monthlyIncome = 0,
    this.allocationPercentages = const AllocationPercentages(),
  });

  SalaryConfig copyWith({
    List<int>? salaryDates,
    double? monthlyIncome,
    AllocationPercentages? allocationPercentages,
  }) {
    return SalaryConfig(
      salaryDates: salaryDates ?? this.salaryDates,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      allocationPercentages:
          allocationPercentages ?? this.allocationPercentages,
    );
  }
}
