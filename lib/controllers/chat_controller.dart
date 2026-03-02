import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_state.dart';
import '../models/salary_config_model.dart';
import '../models/transaction_model.dart';
import '../providers/app_providers.dart';
import '../services/mock_salary_service.dart';

enum ChatFlowStep {
  idle,
  awaitingAmount,
  awaitingDescription,
  awaitingAllocationCategory,
  awaitingAllocationPercent,
  postSaveConfirmation,
}

class ChatControllerState {
  final ConversationState conversationState;
  final ChatFlowStep flowStep;
  final double? pendingAmount;
  final TransactionType? currentTransactionType;
  final String? selectedAllocationGroup;

  const ChatControllerState({
    this.conversationState = ConversationState.home,
    this.flowStep = ChatFlowStep.idle,
    this.pendingAmount,
    this.currentTransactionType,
    this.selectedAllocationGroup,
  });

  ChatControllerState copyWith({
    ConversationState? conversationState,
    ChatFlowStep? flowStep,
    double? pendingAmount,
    TransactionType? currentTransactionType,
    String? selectedAllocationGroup,
    bool clearPendingAmount = false,
    bool clearSelectedAllocationGroup = false,
  }) {
    return ChatControllerState(
      conversationState: conversationState ?? this.conversationState,
      flowStep: flowStep ?? this.flowStep,
      pendingAmount: clearPendingAmount ? null : (pendingAmount ?? this.pendingAmount),
      currentTransactionType: currentTransactionType ?? this.currentTransactionType,
      selectedAllocationGroup: clearSelectedAllocationGroup
          ? null
          : (selectedAllocationGroup ?? this.selectedAllocationGroup),
    );
  }
}

class ChatController extends StateNotifier<ChatControllerState> {
  ChatController(this._ref) : super(const ChatControllerState());

  final Ref _ref;

  Future<void> handleUserInput(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);

    // Salary input flow (independent of guided states, no AI).
    final pendingSalary = _ref.read(pendingSalaryInputProvider);
    if (pendingSalary) {
      await _handlePendingSalaryInput(text);
      return;
    }

    switch (state.conversationState) {
      case ConversationState.home:
        await _handleHomeText(text);
        break;
      case ConversationState.expenseMode:
      case ConversationState.incomeMode:
      case ConversationState.savingsMode:
        await _handleTransactionModeText(text);
        break;
      case ConversationState.allocationMode:
        await _handleAllocationModeText(text);
        break;
    }
  }

  void startExpenseFlow() {
    _startTransactionFlow(kTransactionTypeExpense);
  }

  void startIncomeFlow() {
    _startTransactionFlow(kTransactionTypeIncome);
  }

  void startSavingsFlow() {
    _startTransactionFlow(kTransactionTypeSavings);
  }

  void startAllocationFlow() {
    state = state.copyWith(
      conversationState: ConversationState.allocationMode,
      flowStep: ChatFlowStep.awaitingAllocationCategory,
      clearPendingAmount: true,
      clearSelectedAllocationGroup: true,
      currentTransactionType: null,
    );
    _addAssistantMessage(
      'Which category would you like to modify?',
    );
  }

  void selectAllocationCategory(String group) {
    if (state.conversationState != ConversationState.allocationMode ||
        state.flowStep != ChatFlowStep.awaitingAllocationCategory) {
      return;
    }

    state = state.copyWith(
      selectedAllocationGroup: group,
      flowStep: ChatFlowStep.awaitingAllocationPercent,
    );

    _addUserMessage(_allocationLabelForGroup(group));
    _addAssistantMessage('What percentage should go to ${_allocationLabelForGroup(group)}?');
  }

  void handlePostSaveChoice({required bool addAnother}) {
    switch (state.conversationState) {
      case ConversationState.expenseMode:
      case ConversationState.incomeMode:
      case ConversationState.savingsMode:
        if (addAnother) {
          _restartCurrentTransactionFlow();
        } else {
          _backToHome();
        }
        break;
      case ConversationState.allocationMode:
        if (addAnother) {
          startAllocationFlow();
        } else {
          _backToHome();
        }
        break;
      case ConversationState.home:
        break;
    }
  }

  Future<void> _handleHomeText(String text) async {
    // In home state, never send random text to AI.
    _addAssistantMessage(
      'Please choose what you\'d like to do:',
    );
  }

  Future<void> _handleTransactionModeText(String text) async {
    if (state.flowStep == ChatFlowStep.awaitingAmount) {
      final amount = _parseNumeric(text);
      if (amount == null || amount <= 0) {
        _addAssistantMessage('Please enter a valid number (e.g. 1200).');
        return;
      }

      state = state.copyWith(
        pendingAmount: amount,
        flowStep: ChatFlowStep.awaitingDescription,
      );

      _addAssistantMessage(_descriptionPromptForCurrentMode());
      return;
    }

    if (state.flowStep == ChatFlowStep.awaitingDescription) {
      await _completeTransactionFlow(description: text);
      return;
    }
  }

  Future<void> _handleAllocationModeText(String text) async {
    if (state.flowStep == ChatFlowStep.awaitingAllocationPercent &&
        state.selectedAllocationGroup != null) {
      final percent = _parseNumeric(text);
      if (percent == null || percent < 0 || percent > 100) {
        _addAssistantMessage('Please enter a percentage between 0 and 100.');
        return;
      }

      final salaryService = _ref.read(mockSalaryServiceProvider);
      salaryService.setAllocationAndRecalc(state.selectedAllocationGroup!, percent);
      _ref.read(salaryVersionProvider.notifier).state++;

      final p = salaryService.allocationPercentages;
      final label = _allocationLabelForGroup(state.selectedAllocationGroup!);
      final confirmText =
          '$label updated to ${percent.toStringAsFixed(0)}%.\nNew allocation: Needs ${p.needs.toStringAsFixed(0)}%, Wants ${p.wants.toStringAsFixed(0)}%, Savings ${p.savings.toStringAsFixed(0)}%.';

      _addAssistantMessage(confirmText);
      _addAssistantMessage('Would you like to modify another category?');

      state = state.copyWith(
        flowStep: ChatFlowStep.postSaveConfirmation,
        clearSelectedAllocationGroup: true,
      );
    }
  }

  Future<void> _handlePendingSalaryInput(String text) async {
    _ref.read(pendingSalaryInputProvider.notifier).state = false;
    final amount = _parseNumeric(text);
    final currency = _ref.read(effectiveCurrencyProvider);

    if (amount != null && amount > 0) {
      final salaryService = _ref.read(mockSalaryServiceProvider);
      final rulesService = _ref.read(financialRulesServiceProvider);
      salaryService.setMonthlyIncome(amount);
      _ref.read(salaryVersionProvider.notifier).state++;
      final allocation = salaryService.allocationPercentages;
      final targets = rulesService.calculateTargets(amount, allocation);
      final replyText =
          'Based on your income of ${amount.toStringAsFixed(0)} $currency:\n'
          'Needs: ${targets.targetNeeds.toStringAsFixed(0)}\n'
          'Wants: ${targets.targetWants.toStringAsFixed(0)}\n'
          'Savings: ${targets.targetSavings.toStringAsFixed(0)}\n\n'
          'Want to adjust this?';
      _addAssistantMessage(replyText);
    } else {
      _addAssistantMessage('Please enter a valid amount (e.g. 120000).');
    }
  }

  void _startTransactionFlow(TransactionType type) {
    final newState = switch (type) {
      kTransactionTypeExpense => ConversationState.expenseMode,
      kTransactionTypeIncome => ConversationState.incomeMode,
      kTransactionTypeSavings => ConversationState.savingsMode,
      _ => ConversationState.expenseMode,
    };

    state = state.copyWith(
      conversationState: newState,
      currentTransactionType: type,
      flowStep: ChatFlowStep.awaitingAmount,
      clearPendingAmount: true,
    );

    _addAssistantMessage(_amountPromptForType(type));
  }

  Future<void> _completeTransactionFlow({required String description}) async {
    final amount = state.pendingAmount;
    final type = state.currentTransactionType;
    if (amount == null || type == null) return;

    // Structured input for AIParserService.
    final structuredInput =
        'type: $type; amount: ${amount.toStringAsFixed(2)}; description: $description';

    final parser = _ref.read(mockParserServiceProvider);
    final parsed = await parser.parse(structuredInput);

    if (parsed == null || parsed.amount <= 0) {
      _addAssistantMessage(
        "I couldn't understand that. Please describe it briefly, like 'Groceries' or 'Netflix subscription'.",
      );
      return;
    }

    final txService = _ref.read(mockTransactionServiceProvider);
    final tx = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: parsed.amount,
      category: parsed.category,
      merchant: parsed.merchant,
      createdAt: DateTime.now(),
      type: type,
      categoryGroup: parsed.categoryGroup,
    );
    txService.addTransaction(tx);
    _ref.read(transactionVersionProvider.notifier).state++;

    final label = switch (type) {
      kTransactionTypeExpense => 'Expense',
      kTransactionTypeIncome => 'Income',
      kTransactionTypeSavings => 'Savings',
      _ => 'Entry',
    };

    _addAssistantMessage('$label saved.');
    _addAssistantMessage('Would you like to add another ${label.toLowerCase()}?');

    state = state.copyWith(
      flowStep: ChatFlowStep.postSaveConfirmation,
      clearPendingAmount: true,
    );
  }

  void _restartCurrentTransactionFlow() {
    final type = state.currentTransactionType;
    if (type == null) {
      _backToHome();
      return;
    }

    state = state.copyWith(
      flowStep: ChatFlowStep.awaitingAmount,
      clearPendingAmount: true,
    );

    _addAssistantMessage(_amountPromptForType(type));
  }

  void _backToHome() {
    state = state.copyWith(
      conversationState: ConversationState.home,
      flowStep: ChatFlowStep.idle,
      currentTransactionType: null,
      clearPendingAmount: true,
      clearSelectedAllocationGroup: true,
    );
    _addAssistantMessage('You\'re back at the home menu.');
  }

  double? _parseNumeric(String text) {
    final match = RegExp(r'[\d]+[.,]?\d*').firstMatch(text);
    if (match == null) return null;
    final str = match.group(0)?.replaceAll(',', '.') ?? '';
    return double.tryParse(str);
  }

  String _amountPromptForType(TransactionType type) {
    if (type == kTransactionTypeIncome) {
      return 'How much income did you receive?';
    }
    if (type == kTransactionTypeSavings) {
      return 'How much did you save?';
    }
    return 'How much did you spend?';
  }

  String _descriptionPromptForCurrentMode() {
    switch (state.conversationState) {
      case ConversationState.expenseMode:
        return 'What was it for?';
      case ConversationState.incomeMode:
        return 'Where did this income come from?';
      case ConversationState.savingsMode:
        return 'What are you saving for?';
      case ConversationState.home:
      case ConversationState.allocationMode:
        return 'Can you describe it briefly?';
    }
  }

  String _allocationLabelForGroup(String group) {
    if (group == kSalaryGroupNeeds) return 'Needs';
    if (group == kSalaryGroupWants) return 'Wants';
    if (group == kSalaryGroupSavings) return 'Savings';
    return 'Needs';
  }

  void _addUserMessage(String text) {
    _ref.read(chatMessagesProvider.notifier).add(
          ChatMessageModel(
            id: 'u_${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            role: ChatMessageRole.user,
            createdAt: DateTime.now(),
          ),
        );
  }

  void _addAssistantMessage(String text) {
    _ref.read(chatMessagesProvider.notifier).add(
          ChatMessageModel(
            id: 'a_${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            role: ChatMessageRole.assistant,
            createdAt: DateTime.now(),
          ),
        );
  }
}

