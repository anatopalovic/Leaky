import '../models/salary_config_model.dart';

/// In-memory salary config. Replace with backend/prefs when needed.
class MockSalaryService {
  SalaryConfig _config = const SalaryConfig();

  SalaryConfig get config => _config;

  List<int> get salaryDates => List.unmodifiable(_config.salaryDates);

  double get monthlyIncome => _config.monthlyIncome;

  AllocationPercentages get allocationPercentages =>
      _config.allocationPercentages;

  void setSalaryDates(List<int> dates) {
    _config = _config.copyWith(salaryDates: List.from(dates));
  }

  void addSalaryDate(int day) {
    if (day < 1 || day > 31) return;
    final list = List<int>.from(_config.salaryDates)..add(day);
    list.sort();
    _config = _config.copyWith(salaryDates: list);
  }

  void removeSalaryDate(int day) {
    final list = List<int>.from(_config.salaryDates)..remove(day);
    _config = _config.copyWith(salaryDates: list);
  }

  void setMonthlyIncome(double income) {
    _config = _config.copyWith(monthlyIncome: income);
  }

  void updateAllocationPercentages({
    double? needs,
    double? wants,
    double? savings,
  }) {
    var p = _config.allocationPercentages;
    if (needs != null) p = p.copyWith(needs: needs);
    if (wants != null) p = p.copyWith(wants: wants);
    if (savings != null) p = p.copyWith(savings: savings);
    _config = _config.copyWith(allocationPercentages: p);
  }

  /// Set allocation and normalize remaining two to sum to (100 - set value).
  void setAllocationAndRecalc(String group, double value) {
    if (value < 0 || value > 100) return;
    var p = _config.allocationPercentages;
    final remaining = 100 - value;
    if (group == kSalaryGroupNeeds) {
      p = AllocationPercentages(needs: value, wants: p.wants, savings: p.savings);
      final otherSum = p.wants + p.savings;
      if (otherSum > 0) {
        p = AllocationPercentages(
          needs: value,
          wants: (p.wants / otherSum) * remaining,
          savings: (p.savings / otherSum) * remaining,
        );
      } else {
        p = AllocationPercentages(needs: value, wants: remaining / 2, savings: remaining / 2);
      }
    } else if (group == kSalaryGroupWants) {
      p = AllocationPercentages(needs: p.needs, wants: value, savings: p.savings);
      final otherSum = p.needs + p.savings;
      if (otherSum > 0) {
        p = AllocationPercentages(
          needs: (p.needs / otherSum) * remaining,
          wants: value,
          savings: (p.savings / otherSum) * remaining,
        );
      } else {
        p = AllocationPercentages(needs: remaining / 2, wants: value, savings: remaining / 2);
      }
    } else if (group == kSalaryGroupSavings) {
      p = AllocationPercentages(needs: p.needs, wants: p.wants, savings: value);
      final otherSum = p.needs + p.wants;
      if (otherSum > 0) {
        p = AllocationPercentages(
          needs: (p.needs / otherSum) * remaining,
          wants: (p.wants / otherSum) * remaining,
          savings: value,
        );
      } else {
        p = AllocationPercentages(needs: remaining / 2, wants: remaining / 2, savings: value);
      }
    }
    _config = _config.copyWith(allocationPercentages: p);
  }
}

const String kSalaryGroupNeeds = 'needs';
const String kSalaryGroupWants = 'wants';
const String kSalaryGroupSavings = 'savings';
