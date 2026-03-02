import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message_model.dart';
import '../../models/transaction_model.dart';
import '../../models/conversation_state.dart';
import '../../providers/app_providers.dart';
import '../../controllers/chat_controller.dart';
import '../../services/mock_salary_service.dart';
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

    ref.read(chatControllerProvider.notifier).handleUserInput(text);
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final chatState = ref.watch(chatControllerProvider);

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
              itemCount: messages.isEmpty && chatState.conversationState == ConversationState.home
                  ? 1
                  : messages.length,
              itemBuilder: (context, i) {
                if (messages.isEmpty && chatState.conversationState == ConversationState.home) {
                  return ChatBubble(
                    text: 'Hi 👋 What would you like to do next?',
                    isUser: false,
                  );
                }
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConversationChips(chatState: chatState, ref: ref),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type here...',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationChips extends StatelessWidget {
  const _ConversationChips({
    required this.chatState,
    required this.ref,
  });

  final ChatControllerState chatState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (chatState.conversationState == ConversationState.home) {
      chips.addAll([
        _buildChip(
          context,
          label: '➕ Add Expense',
          onTap: () => ref.read(chatControllerProvider.notifier).startExpenseFlow(),
        ),
        _buildChip(
          context,
          label: '💰 Add Income',
          onTap: () => ref.read(chatControllerProvider.notifier).startIncomeFlow(),
        ),
        _buildChip(
          context,
          label: '🏦 Add Savings',
          onTap: () => ref.read(chatControllerProvider.notifier).startSavingsFlow(),
        ),
      ]);
    } else if (chatState.conversationState == ConversationState.expenseMode &&
        chatState.flowStep == ChatFlowStep.postSaveConfirmation) {
      chips.addAll(_buildPostSaveChips(context, 'expense'));
    } else if (chatState.conversationState == ConversationState.incomeMode &&
        chatState.flowStep == ChatFlowStep.postSaveConfirmation) {
      chips.addAll(_buildPostSaveChips(context, 'income'));
    } else if (chatState.conversationState == ConversationState.savingsMode &&
        chatState.flowStep == ChatFlowStep.postSaveConfirmation) {
      chips.addAll(_buildPostSaveChips(context, 'savings'));
    } else if (chatState.conversationState == ConversationState.expenseMode &&
        chatState.flowStep == ChatFlowStep.awaitingCategorySelection) {
      chips.addAll([
        _buildChip(
          context,
          label: 'Needs',
          onTap: () => ref.read(chatControllerProvider.notifier).selectExpenseCategory(kCategoryGroupNeeds),
        ),
        _buildChip(
          context,
          label: 'Wants',
          onTap: () => ref.read(chatControllerProvider.notifier).selectExpenseCategory(kCategoryGroupWants),
        ),
        _buildChip(
          context,
          label: 'Misc',
          onTap: () => ref.read(chatControllerProvider.notifier).selectExpenseCategory(kCategoryGroupWants),
        ),
      ]);
    } else if (chatState.conversationState == ConversationState.incomeMode &&
        chatState.flowStep == ChatFlowStep.awaitingAllocationChoice) {
      chips.addAll([
        _buildChip(
          context,
          label: 'Allocate manually',
          onTap: () => ref.read(chatControllerProvider.notifier).handleIncomeAllocationChoice(choice: 'manual'),
        ),
        _buildChip(
          context,
          label: 'Use recommended (50/30/20)',
          onTap: () => ref.read(chatControllerProvider.notifier).handleIncomeAllocationChoice(choice: 'recommended'),
        ),
        _buildChip(
          context,
          label: 'Skip',
          onTap: () => ref.read(chatControllerProvider.notifier).handleIncomeAllocationChoice(choice: 'skip'),
        ),
      ]);
    } else if (chatState.conversationState == ConversationState.allocationMode &&
        chatState.flowStep == ChatFlowStep.awaitingAllocationCategory) {
      chips.addAll([
        _buildChip(
          context,
          label: 'Needs',
          onTap: () =>
              ref.read(chatControllerProvider.notifier).selectAllocationCategory(kSalaryGroupNeeds),
        ),
        _buildChip(
          context,
          label: 'Wants',
          onTap: () =>
              ref.read(chatControllerProvider.notifier).selectAllocationCategory(kSalaryGroupWants),
        ),
        _buildChip(
          context,
          label: 'Savings',
          onTap: () => ref
              .read(chatControllerProvider.notifier)
              .selectAllocationCategory(kSalaryGroupSavings),
        ),
      ]);
    } else if (chatState.conversationState == ConversationState.allocationMode &&
        chatState.flowStep == ChatFlowStep.postSaveConfirmation) {
      chips.addAll(_buildModifyAgainChips(context));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  List<Widget> _buildPostSaveChips(BuildContext context, String labelLower) {
    return [
      _buildChip(
        context,
        label: 'Add another',
        onTap: () => ref.read(chatControllerProvider.notifier).handlePostSaveChoice(
              addAnother: true,
            ),
      ),
      _buildChip(
        context,
        label: 'Exit',
        onTap: () => ref.read(chatControllerProvider.notifier).handlePostSaveChoice(
              addAnother: false,
            ),
      ),
    ];
  }

  List<Widget> _buildModifyAgainChips(BuildContext context) {
    return [
      _buildChip(
        context,
        label: 'Modify again',
        onTap: () => ref.read(chatControllerProvider.notifier).handlePostSaveChoice(
              addAnother: true,
            ),
      ),
      _buildChip(
        context,
        label: 'Exit',
        onTap: () => ref.read(chatControllerProvider.notifier).handlePostSaveChoice(
              addAnother: false,
            ),
      ),
    ];
  }

  Widget _buildChip(BuildContext context,
      {required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

