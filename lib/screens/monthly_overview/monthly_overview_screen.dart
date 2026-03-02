import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/app_providers.dart';
import '../../services/financial_rules_service.dart';
import '../../widgets/monthly_insight_button.dart';

/// Monthly spending overview: total, category breakdown, top 3, yearly projection.
class MonthlyOverviewScreen extends ConsumerWidget {
  const MonthlyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionVersionProvider); // Rebuild when transactions reset/demo
    ref.watch(salaryVersionProvider);
    final txService = ref.watch(mockTransactionServiceProvider);
    final salaryService = ref.watch(mockSalaryServiceProvider);
    final rulesService = ref.watch(financialRulesServiceProvider);
    final currency = ref.watch(effectiveCurrencyProvider);

    final incomeTotal = txService.currentMonthIncome;
    final expensesTotal = txService.currentMonthExpenses;
    final savingsTotal = txService.currentMonthSavings;
    final investmentsTotal = txService.currentMonthInvestments;
    final netTotal = txService.currentMonthNet;
    final byCategory = txService.currentMonthByCategory;
    final top3 = txService.topCategories(3);
    final yearly = txService.yearlyProjection;
    final income = salaryService.monthlyIncome;
    final allocation = salaryService.allocationPercentages;
    final byGroup = txService.currentMonthByCategoryGroup;
    final evaluation = income > 0
        ? rulesService.evaluateMonth(income, allocation, byGroup)
        : null;
    final insightText = evaluation != null
        ? rulesService.insightFromEvaluation(evaluation, currency)
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'This month',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey.shade700),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _SummaryCard(
            title: 'Income',
            value: '${incomeTotal.toStringAsFixed(0)} $currency',
          ),
          _SummaryCard(
            title: 'Expenses',
            value: '${expensesTotal.toStringAsFixed(0)} $currency',
          ),
          _SummaryCard(
            title: 'Savings',
            value: '${savingsTotal.toStringAsFixed(0)} $currency',
          ),
          _SummaryCard(
            title: 'Investments',
            value: '${investmentsTotal.toStringAsFixed(0)} $currency',
          ),
          _SummaryCard(
            title: 'Net',
            subtitle: 'Income − Expenses − Savings − Investments',
            value: '${netTotal.toStringAsFixed(0)} $currency',
          ),
          if (evaluation != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Target vs Actual',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _TargetActualCard(
              title: 'Income',
              target: income,
              actual: null,
              currency: currency,
            ),
            _TargetActualCard(
              title: 'Needs',
              target: evaluation.targetNeeds,
              actual: evaluation.actualNeeds,
              currency: currency,
              diff: evaluation.deviationNeeds,
            ),
            _TargetActualCard(
              title: 'Wants',
              target: evaluation.targetWants,
              actual: evaluation.actualWants,
              currency: currency,
              diff: evaluation.deviationWants,
            ),
            _TargetActualCard(
              title: 'Savings',
              target: evaluation.targetSavings,
              actual: evaluation.actualSavings,
              currency: currency,
              diff: evaluation.deviationSavings,
            ),
            if (insightText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insightText,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const Text(
            'By category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (byCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No expenses this month yet.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: BarChart(
                _barChartData(top3, currency),
                swapAnimationDuration: const Duration(milliseconds: 300),
              ),
            ),
            const SizedBox(height: 16),
            ...top3.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 15)),
                    Text(
                      '${e.value.toStringAsFixed(0)} $currency',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SummaryCard(
            title: 'Yearly projection',
            subtitle: 'If this month repeated × 12',
            value: '${yearly.toStringAsFixed(0)} $currency',
          ),
          const SizedBox(height: 32),
          const MonthlyInsightButton(),
        ],
      ),
    );
  }

  BarChartData _barChartData(
    List<MapEntry<String, double>> top3,
    String currency,
  ) {
    final maxY = top3.isEmpty
        ? 1.0
        : top3.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < top3.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    top3[i].key,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            reservedSize: 28,
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.shade200,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: top3.asMap().entries.map((entry) {
        final i = entry.key;
        final v = entry.value.value;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              color: Colors.grey.shade700,
              width: 24,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
          showingTooltipIndicators: [],
        );
      }).toList(),
    );
  }
}

class _TargetActualCard extends StatelessWidget {
  const _TargetActualCard({
    required this.title,
    required this.target,
    required this.actual,
    required this.currency,
    this.diff,
  });

  final String title;
  final double target;
  final double? actual;
  final String currency;
  final double? diff;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(
                '${target.toStringAsFixed(0)} $currency',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (actual != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${actual!.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (diff != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${diff! >= 0 ? "+" : ""}${diff!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: diff! > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
