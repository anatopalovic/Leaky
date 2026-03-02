import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message_model.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../home/chat_screen.dart';

/// Settings screen: Account, Subscription (mocked), Preferences, Data.
/// Accessible from top-right gear on Home. All state from providers; no hardcoded state.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isPremium = ref.watch(subscriptionStatusProvider);
    final settings = ref.watch(settingsProvider);
    final effectiveCurrency = ref.watch(effectiveCurrencyProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
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
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          _AccountSection(
            user: user,
            effectiveCurrency: effectiveCurrency,
            ref: ref,
          ),
          const SizedBox(height: 32),
          _SectionHeader(title: 'Salary Dates'),
          const SizedBox(height: 8),
          _SalarySection(ref: ref),
          const SizedBox(height: 32),
          _SectionHeader(title: 'Subscription'),
          const SizedBox(height: 8),
          _SubscriptionSection(isPremium: isPremium, ref: ref),
          const SizedBox(height: 32),
          _SectionHeader(title: 'Preferences'),
          const SizedBox(height: 8),
          _PreferencesSection(settings: settings, ref: ref),
          const SizedBox(height: 32),
          _SectionHeader(title: 'Data'),
          const SizedBox(height: 8),
          _DataSection(ref: ref),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.user,
    required this.effectiveCurrency,
    required this.ref,
  });

  final UserModel? user;
  final String effectiveCurrency;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? 'user@example.com';
    final income = user?.monthlyIncome ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Email',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            subtitle: Text(
              email,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              'Currency',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            subtitle: Text(
              effectiveCurrency,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              'Monthly income',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            subtitle: Text(
              '$income $effectiveCurrency',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            onTap: () {
              ref.read(currentUserProvider.notifier).signOut();
              // App rebuilds; home becomes LoginScreen.
            },
          ),
        ],
      ),
    );
  }
}

class _SalarySection extends StatelessWidget {
  const _SalarySection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    ref.watch(salaryVersionProvider);
    final salaryService = ref.watch(mockSalaryServiceProvider);
    final dates = salaryService.salaryDates;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Salary dates'),
            subtitle: Text(
              dates.isEmpty
                  ? 'No dates set (e.g. 5, 20)'
                  : dates.map((d) => d.toString()).join(', '),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Add date'),
            trailing: const Icon(Icons.add),
            onTap: () => _showAddSalaryDateDialog(context, ref),
          ),
          if (dates.isNotEmpty) ...[
            const Divider(height: 1),
            ...dates.map(
              (day) => ListTile(
                title: Text('Day $day'),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                  onPressed: () {
                    ref.read(mockSalaryServiceProvider).removeSalaryDate(day);
                    ref.read(salaryVersionProvider.notifier).state++;
                  },
                ),
              ),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            title: const Text('Simulate Salary Day'),
            subtitle: Text(
              'Ask in chat how much you received',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            onTap: () {
              ref.read(chatMessagesProvider.notifier).add(
                    ChatMessageModel(
                      id: 'salary_${DateTime.now().millisecondsSinceEpoch}',
                      text: '💰 Your salary hit today. How much did you receive?',
                      role: ChatMessageRole.assistant,
                      createdAt: DateTime.now(),
                    ),
                  );
              ref.read(pendingSalaryInputProvider.notifier).state = true;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddSalaryDateDialog(BuildContext context, WidgetRef ref) {
    int selectedDay = 1;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add salary date'),
          content: DropdownButton<int>(
            value: selectedDay,
            isExpanded: true,
            items: List.generate(31, (i) => i + 1)
                .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedDay = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(mockSalaryServiceProvider).addSalaryDate(selectedDay);
                ref.read(salaryVersionProvider.notifier).state++;
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({
    required this.isPremium,
    required this.ref,
  });

  final bool isPremium;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Status'),
            subtitle: Text(
              isPremium ? 'Premium' : 'Free Plan',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Upgrade to Premium'),
            trailing: isPremium
                ? Icon(Icons.check_circle, color: Colors.green.shade600)
                : null,
            onTap: isPremium
                ? null
                : () {
                    ref.read(subscriptionStatusProvider.notifier).upgradeToPremium();
                  },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Restore Purchases'),
            onTap: () {
              ref.read(mockSubscriptionServiceProvider).restorePurchases();
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restore'),
                  content: const Text('Purchases restored (mocked).'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.settings,
    required this.ref,
  });

  final SettingsModel settings;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Currency'),
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox.shrink(),
              items: SettingsModel.supportedCurrencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setCurrency(v);
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Enable Smart Insights'),
            trailing: Switch(
              value: settings.smartInsightsEnabled,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setSmartInsightsEnabled(v);
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Monthly Leak Notifications'),
            subtitle: Text(
              'Mocked',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            trailing: Switch(
              value: settings.monthlyLeakNotificationsEnabled,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setMonthlyLeakNotificationsEnabled(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Reset All Transactions',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () => _confirmReset(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text(
              'Generate Demo Data',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Add 20 fake transactions',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            onTap: () {
              ref.read(mockTransactionServiceProvider).generateDemoData();
              ref.read(transactionVersionProvider.notifier).state++;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo data added')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset transactions?'),
        content: const Text(
          'All transactions will be cleared. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(mockTransactionServiceProvider).clear();
              ref.read(transactionVersionProvider.notifier).state++;
              Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All transactions cleared')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
