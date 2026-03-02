import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message_model.dart';
import '../../models/salary_config_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../services/financial_rules_service.dart';
import '../../services/mock_parser_service.dart';
import '../../services/mock_salary_service.dart';
import '../../services/mock_transaction_service.dart';
import '../../widgets/chat_bubble.dart';
import '../monthly_overview/monthly_overview_screen.dart';
import '../settings/settings_screen.dart';

/// Chat-first main screen. Send message → parse → save transaction → coach reply.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final currency = ref.read(effectiveCurrencyProvider);

    // Add user message
    ref.read(chatMessagesProvider.notifier).add(
          ChatMessageModel(
            id: 'u_${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            role: ChatMessageRole.user,
            createdAt: DateTime.now(),
          ),
        );

    String replyText;

    // 1) Pending salary amount (after "Simulate Salary Day")
    final pendingSalary = ref.read(pendingSalaryInputProvider);
    if (pendingSalary) {
      ref.read(pendingSalaryInputProvider.notifier).state = false;
      final amount = _parseAmountFromText(text);
      if (amount != null && amount > 0) {
        final salaryService = ref.read(mockSalaryServiceProvider);
        final rulesService = ref.read(financialRulesServiceProvider);
        salaryService.setMonthlyIncome(amount);
        ref.read(salaryVersionProvider.notifier).state++;
        final allocation = salaryService.allocationPercentages;
        final targets = rulesService.calculateTargets(amount, allocation);
        replyText =
            'Based on your income of ${amount.toStringAsFixed(0)} $currency:\n'
            'Needs: ${targets.targetNeeds.toStringAsFixed(0)}\n'
            'Wants: ${targets.targetWants.toStringAsFixed(0)}\n'
            'Savings: ${targets.targetSavings.toStringAsFixed(0)}\n\n'
            'Want to adjust this?';
      } else {
        replyText = 'Please enter a valid amount (e.g. 120000).';
      }
      _addAssistantMessage(replyText);
      _scrollToBottom();
      return;
    }

    // 2) Allocation adjustment: "Set savings to 30%" / "Change needs to 40%"
    final allocationMatch = _parseAllocationAdjustment(text);
    if (allocationMatch != null) {
      final salaryService = ref.read(mockSalaryServiceProvider);
      salaryService.setAllocationAndRecalc(allocationMatch.group, allocationMatch.percent);
      ref.read(salaryVersionProvider.notifier).state++;
      final p = salaryService.allocationPercentages;
      replyText =
          '${_capitalize(allocationMatch.group)} updated to ${allocationMatch.percent.toInt()}%.\n'
          'New targets: Needs ${p.needs.toStringAsFixed(0)}%, Wants ${p.wants.toStringAsFixed(0)}%, Savings ${p.savings.toStringAsFixed(0)}%.';
      _addAssistantMessage(replyText);
      _scrollToBottom();
      return;
    }

    // 3) Transaction parse (expense)
    final parser = ref.read(mockParserServiceProvider);
    final parsed = parser.parse(text);

    if (parsed == null) {
      replyText =
          "I couldn't find an amount in that. Try something like \"Coffee 250\" or \"Netflix 9.99\".";
    } else {
      final txService = ref.read(mockTransactionServiceProvider);
      final insight = ref.read(insightServiceProvider);
      final tx = _createTransaction(parsed);
      txService.addTransaction(tx);
      final categoryTotal =
          txService.currentMonthByCategory[parsed.category] ?? 0.0;
      replyText = insight.buildCoachResponse(
        amount: parsed.amount,
        category: parsed.category,
        merchant: parsed.merchant,
        currency: currency,
        categoryTotalThisMonth: categoryTotal,
      );
    }

    _addAssistantMessage(replyText);
    _scrollToBottom();
  }

  double? _parseAmountFromText(String text) {
    final match = RegExp(r'[\d]+[.,]?\d*').firstMatch(text);
    if (match == null) return null;
    final str = match.group(0)?.replaceAll(',', '.') ?? '';
    return double.tryParse(str);
  }

  ({String group, double percent})? _parseAllocationAdjustment(String text) {
    final lower = text.trim().toLowerCase();
    final percentMatch = RegExp(r'(\d+)\s*%?').firstMatch(lower);
    if (percentMatch == null) return null;
    final percent = double.tryParse(percentMatch.group(1) ?? '') ?? 0;
    if (percent < 0 || percent > 100) return null;
    if (lower.contains('needs')) return (group: kSalaryGroupNeeds, percent: percent);
    if (lower.contains('wants')) return (group: kSalaryGroupWants, percent: percent);
    if (lower.contains('savings')) return (group: kSalaryGroupSavings, percent: percent);
    return null;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  void _addAssistantMessage(String text) {
    ref.read(chatMessagesProvider.notifier).add(
          ChatMessageModel(
            id: 'a_${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            role: ChatMessageRole.assistant,
            createdAt: DateTime.now(),
          ),
        );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TransactionModel _createTransaction(ParsedTransaction parsed) {
    return TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: parsed.amount,
      category: parsed.category,
      merchant: parsed.merchant,
      createdAt: DateTime.now(),
      type: kTransactionTypeExpense,
      categoryGroup: parsed.categoryGroup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Leaky',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: Colors.grey.shade700),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MonthlyOverviewScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                return ChatBubble(
                  text: msg.text,
                  isUser: msg.role == ChatMessageRole.user,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'e.g. Coffee 250, Wolt 1450',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
