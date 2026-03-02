import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_state.dart';
import '../models/salary_config_model.dart';
import '../models/transaction_model.dart';
import '../providers/app_providers.dart';
import '../services/financial_rules_service.dart';
import '../services/mock_parser_service.dart';
import '../services/mock_salary_service.dart';

enum ChatFlowStep {
  idle,
  awaitingAmount,
  awaitingDescription,
  awaitingCategorySelection,
  awaitingAllocationCategory,
  awaitingAllocationPercent,
  postSaveConfirmation,
  // Income allocation
  awaitingAllocationChoice,
  awaitingManualSpending,
  awaitingManualSavings,
  awaitingManualInvestments,
}

class ChatControllerState {
  final ConversationState conversationState;
  final ChatFlowStep flowStep;
  final double? pendingAmount;
  final String? pendingDescription;
  final TransactionType? currentTransactionType;
  final String? selectedAllocationGroup;
  final double? pendingIncomeAmount;
  final double? allocationSpending;
  final double? allocationSavings;
  final double? allocationInvestments;

  const ChatControllerState({
    this.conversationState = ConversationState.home,
    this.flowStep = ChatFlowStep.idle,
    this.pendingAmount,
    this.pendingDescription,
    this.currentTransactionType,
    this.selectedAllocationGroup,
    this.pendingIncomeAmount,
    this.allocationSpending,
    this.allocationSavings,
    this.allocationInvestments,
  });

  ChatControllerState copyWith({
    ConversationState? conversationState,
    ChatFlowStep? flowStep,
    double? pendingAmount,
    String? pendingDescription,
    TransactionType? currentTransactionType,
    String? selectedAllocationGroup,
    double? pendingIncomeAmount,
    double? allocationSpending,
    double? allocationSavings,
    double? allocationInvestments,
    bool clearPendingAmount = false,
    bool clearPendingDescription = false,
    bool clearSelectedAllocationGroup = false,
    bool clearAllocationAmounts = false,
  }) {
    return ChatControllerState(
      conversationState: conversationState ?? this.conversationState,
      flowStep: flowStep ?? this.flowStep,
      pendingAmount: clearPendingAmount ? null : (pendingAmount ?? this.pendingAmount),
      pendingDescription: clearPendingDescription ? null : (pendingDescription ?? this.pendingDescription),
      currentTransactionType: currentTransactionType ?? this.currentTransactionType,
      selectedAllocationGroup: clearSelectedAllocationGroup
          ? null
          : (selectedAllocationGroup ?? this.selectedAllocationGroup),
      pendingIncomeAmount: pendingIncomeAmount ?? this.pendingIncomeAmount,
      allocationSpending: clearAllocationAmounts ? null : (allocationSpending ?? this.allocationSpending),
      allocationSavings: clearAllocationAmounts ? null : (allocationSavings ?? this.allocationSavings),
      allocationInvestments: clearAllocationAmounts ? null : (allocationInvestments ?? this.allocationInvestments),
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

  void handleIncomeAllocationChoice({required String choice}) {
    if (state.conversationState != ConversationState.incomeMode ||
        state.flowStep != ChatFlowStep.awaitingAllocationChoice) return;
    final income = state.pendingIncomeAmount ?? 0;
    final currency = _ref.read(effectiveCurrencyProvider);

    if (choice == 'skip') {
      _addAssistantMessage('Skipped. Income recorded.');
      state = state.copyWith(
        flowStep: ChatFlowStep.postSaveConfirmation,
        pendingIncomeAmount: null,
        clearAllocationAmounts: true,
      );
      _addAssistantMessage('Would you like to add another income?');
      return;
    }

    if (choice == 'recommended') {
      final rulesService = _ref.read(financialRulesServiceProvider);
      final allocation = FinancialRulesService.defaultAllocation;
      final targets = rulesService.calculateTargets(income, allocation);
      _addAssistantMessage(
        'Using 50/30/20: Needs ${targets.targetNeeds.toStringAsFixed(0)}, '
        'Wants ${targets.targetWants.toStringAsFixed(0)}, '
        'Savings ${targets.targetSavings.toStringAsFixed(0)} $currency.',
      );
      state = state.copyWith(
        flowStep: ChatFlowStep.postSaveConfirmation,
        pendingIncomeAmount: null,
        clearAllocationAmounts: true,
      );
      _addAssistantMessage('Would you like to add another income?');
      return;
    }

    if (choice == 'manual') {
      state = state.copyWith(
        flowStep: ChatFlowStep.awaitingManualSpending,
        clearAllocationAmounts: true,
      );
      _addAssistantMessage('How much for spending?');
    }
  }

  void _completeManualIncomeAllocation({required double investments}) {
    final income = state.pendingIncomeAmount ?? 0;
    final spending = state.allocationSpending ?? 0;
    final savings = state.allocationSavings ?? 0;
    final txService = _ref.read(mockTransactionServiceProvider);
    final currency = _ref.read(effectiveCurrencyProvider);

    if (savings > 0) {
      txService.addTransaction(TransactionModel(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}_s',
        amount: savings,
        category: 'Allocated savings',
        merchant: null,
        createdAt: DateTime.now(),
        type: kTransactionTypeSavings,
        categoryGroup: kCategoryGroupSavings,
      ));
    }
    if (investments > 0) {
      txService.addTransaction(TransactionModel(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}_i',
        amount: investments,
        category: 'Allocated investments',
        merchant: null,
        createdAt: DateTime.now(),
        type: kTransactionTypeInvestment,
        categoryGroup: kCategoryGroupSavings,
      ));
    }
    _ref.read(transactionVersionProvider.notifier).state++;
    _addAssistantMessage(
      'Allocation recorded: spending $spending, savings $savings, investments $investments $currency.',
    );
    state = state.copyWith(
      flowStep: ChatFlowStep.postSaveConfirmation,
      pendingIncomeAmount: null,
      clearAllocationAmounts: true,
    );
    _addAssistantMessage('Would you like to add another income?');
  }

  Future<void> _handleHomeText(String text) async {
    // In home state, never send to AI. Typing stays enabled; prompt to use buttons.
    _addAssistantMessage(
      'Please choose what you\'d like to do next.',
    );
  }

  Future<void> _handleTransactionModeText(String text) async {
    // Post-save: allow typing "add another" / "exit"
    if (state.flowStep == ChatFlowStep.postSaveConfirmation) {
      _handlePostSaveText(text);
      return;
    }

    if (state.flowStep == ChatFlowStep.awaitingAmount) {
      final isExpense = state.conversationState == ConversationState.expenseMode;
      final hasNumber = _parseNumeric(text) != null;
      final hasNonNumericText = _hasNonNumericText(text);

      if (isExpense && hasNumber && hasNonNumericText) {
        await _handleExpenseAmountAndText(text);
        return;
      }

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

    if (state.conversationState == ConversationState.incomeMode &&
        state.flowStep == ChatFlowStep.awaitingAllocationChoice) {
      _addAssistantMessage('Please choose an option: Allocate manually, Use recommended, or Skip.');
      return;
    }

    if (state.conversationState == ConversationState.incomeMode &&
        state.flowStep == ChatFlowStep.awaitingManualSpending) {
      final value = _parseNumeric(text);
      if (value == null || value < 0) {
        _addAssistantMessage('Please enter a valid amount.');
        return;
      }
      state = state.copyWith(
        allocationSpending: value,
        flowStep: ChatFlowStep.awaitingManualSavings,
      );
      _addAssistantMessage('How much for savings?');
      return;
    }

    if (state.conversationState == ConversationState.incomeMode &&
        state.flowStep == ChatFlowStep.awaitingManualSavings) {
      final value = _parseNumeric(text);
      if (value == null || value < 0) {
        _addAssistantMessage('Please enter a valid amount.');
        return;
      }
      state = state.copyWith(
        allocationSavings: value,
        flowStep: ChatFlowStep.awaitingManualInvestments,
      );
      _addAssistantMessage('How much for investments?');
      return;
    }

    if (state.conversationState == ConversationState.incomeMode &&
        state.flowStep == ChatFlowStep.awaitingManualInvestments) {
      final value = _parseNumeric(text);
      if (value == null || value < 0) {
        _addAssistantMessage('Please enter a valid amount.');
        return;
      }
      final income = state.pendingIncomeAmount ?? 0;
      final spending = state.allocationSpending ?? 0;
      final savings = state.allocationSavings ?? 0;
      final total = spending + savings + value;
      if (total > income) {
        _addAssistantMessage(
          'Total ($total) exceeds income ($income). Please enter amounts that add up to no more than $income.',
        );
        return;
      }
      _completeManualIncomeAllocation(investments: value);
      return;
    }

    if (state.flowStep == ChatFlowStep.awaitingCategorySelection) {
      final group = _parseCategoryGroupFromText(text);
      if (group != null) {
        selectExpenseCategory(group);
        return;
      }
      _addAssistantMessage('Please choose Needs, Wants, or Misc.');
    }
  }

  String? _parseCategoryGroupFromText(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.contains('need')) return kCategoryGroupNeeds;
    if (lower.contains('want')) return kCategoryGroupWants;
    if (lower == 'misc' || lower.contains('misc')) return kCategoryGroupWants;
    return null;
  }

  void selectExpenseCategory(String categoryGroup) {
    if (state.flowStep != ChatFlowStep.awaitingCategorySelection ||
        state.pendingAmount == null) return;
    final amount = state.pendingAmount!;
    final description = state.pendingDescription ?? 'Misc';
    final txService = _ref.read(mockTransactionServiceProvider);
    final tx = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      category: description.length > 30 ? 'Misc' : description,
      merchant: null,
      createdAt: DateTime.now(),
      type: kTransactionTypeExpense,
      categoryGroup: categoryGroup,
    );
    txService.addTransaction(tx);
    _ref.read(transactionVersionProvider.notifier).state++;
    _addAssistantMessage('Expense saved.');
    _addAssistantMessage('Would you like to add another expense?');
    state = state.copyWith(
      flowStep: ChatFlowStep.postSaveConfirmation,
      clearPendingAmount: true,
      clearPendingDescription: true,
    );
  }

  void _handlePostSaveText(String text) {
    final lower = text.trim().toLowerCase();
    final addAnother = lower.contains('add') && (lower.contains('another') || lower.contains('more'));
    final exit = lower.contains('exit') || lower == 'no' || lower == 'n';
    if (addAnother) {
      handlePostSaveChoice(addAnother: true);
      return;
    }
    if (exit) {
      handlePostSaveChoice(addAnother: false);
      return;
    }
    if (state.conversationState == ConversationState.allocationMode) {
      _addAssistantMessage(
        'Sorry, I didn\'t get that. Would you like to modify another category?',
      );
    } else {
      final label = _postSaveLabel();
      _addAssistantMessage(
        'Sorry, I didn\'t get that. Would you like to add another $label?',
      );
    }
  }

  String _postSaveLabel() {
    switch (state.conversationState) {
      case ConversationState.expenseMode:
        return 'expense';
      case ConversationState.incomeMode:
        return 'income';
      case ConversationState.savingsMode:
        return 'savings';
      case ConversationState.allocationMode:
        return 'modification';
      case ConversationState.home:
        return 'entry';
    }
  }

  Future<void> _handleExpenseAmountAndText(String text) async {
    final parser = _ref.read(mockParserServiceProvider);
    final parsed = await parser.parse(text);
    if (parsed != null && parsed.amount > 0) {
      _saveExpenseFromParsed(parsed);
      return;
    }
    final amount = _parseNumeric(text);
    if (amount != null && amount > 0) {
      state = state.copyWith(
        pendingAmount: amount,
        pendingDescription: text,
        flowStep: ChatFlowStep.awaitingCategorySelection,
        clearPendingDescription: false,
      );
      _addAssistantMessage('Which category does this belong to?');
      return;
    }
    _addAssistantMessage('Please enter a valid number (e.g. 1200).');
  }

  void _saveExpenseFromParsed(ParsedTransaction parsed) {
    final txService = _ref.read(mockTransactionServiceProvider);
    final tx = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: parsed.amount,
      category: parsed.category,
      merchant: parsed.merchant,
      createdAt: DateTime.now(),
      type: kTransactionTypeExpense,
      categoryGroup: parsed.categoryGroup,
    );
    txService.addTransaction(tx);
    _ref.read(transactionVersionProvider.notifier).state++;
    _addAssistantMessage('Expense saved.');
    _addAssistantMessage('Would you like to add another expense?');
    state = state.copyWith(
      flowStep: ChatFlowStep.postSaveConfirmation,
      clearPendingAmount: true,
      clearPendingDescription: true,
    );
  }

  Future<void> _handleAllocationModeText(String text) async {
    if (state.flowStep == ChatFlowStep.postSaveConfirmation) {
      _handlePostSaveText(text);
      return;
    }
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

    if (type == kTransactionTypeIncome) {
      _addAssistantMessage('Income saved.');
      _addAssistantMessage('How would you like to allocate this income?');
      state = state.copyWith(
        flowStep: ChatFlowStep.awaitingAllocationChoice,
        pendingIncomeAmount: amount,
        clearPendingAmount: true,
      );
      return;
    }

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
    _addAssistantMessage('All set 👍 What would you like to do next?');
  }

  double? _parseNumeric(String text) {
    final match = RegExp(r'[\d]+[.,]?\d*').firstMatch(text);
    if (match == null) return null;
    final str = match.group(0)?.replaceAll(',', '.') ?? '';
    return double.tryParse(str);
  }

  bool _hasNonNumericText(String text) {
    final withoutNumber = text.replaceAll(RegExp(r'[\d\s.,]+'), '').trim();
    return withoutNumber.length > 0;
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

