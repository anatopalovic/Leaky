import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// "Generate Monthly Insight" → shows dialog with mocked monthly summary.
class MonthlyInsightButton extends ConsumerWidget {
  const MonthlyInsightButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.read(insightServiceProvider);
    final currency = ref.watch(effectiveCurrencyProvider);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          final text = insight.getMonthlyInsight(currency);
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Monthly insight'),
              content: Text(text),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Generate Monthly Insight'),
      ),
    );
  }
}
