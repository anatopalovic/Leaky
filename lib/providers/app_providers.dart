import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../services/ai_parser_service.dart';
import '../services/financial_rules_service.dart';
import '../services/insight_service.dart';
import '../services/mock_auth_service.dart';
import '../services/mock_salary_service.dart';
import '../services/mock_subscription_service.dart';
import '../services/mock_transaction_service.dart';
import '../controllers/chat_controller.dart';

/// Replace with real auth provider when using Supabase.
final mockAuthServiceProvider = Provider<MockAuthService>((ref) => MockAuthService());

/// Replace with real transaction persistence when using backend.
final mockTransactionServiceProvider =
    Provider<MockTransactionService>((ref) => MockTransactionService());

/// AI-backed parser (OpenAI) with local regex fallback.
final mockParserServiceProvider = Provider<AIParserService>((ref) => AIParserService());

final insightServiceProvider = Provider<InsightService>((ref) {
  return InsightService(ref.watch(mockTransactionServiceProvider));
});

/// Mock subscription. Replace with RevenueCat-backed service when integrating IAP.
final mockSubscriptionServiceProvider =
    Provider<MockSubscriptionService>((ref) => MockSubscriptionService());

/// Premium status; UI watches this. Notifier calls MockSubscriptionService (replaceable).
final subscriptionStatusProvider =
    StateNotifierProvider<SubscriptionStatusNotifier, bool>((ref) {
  return SubscriptionStatusNotifier(ref.read(mockSubscriptionServiceProvider));
});

class SubscriptionStatusNotifier extends StateNotifier<bool> {
  SubscriptionStatusNotifier(this._service) : super(false);

  final MockSubscriptionService _service;

  void upgradeToPremium() {
    _service.upgradeToPremium();
    state = true;
  }
}

/// App preferences (currency, toggles). Live updates; replace with persisted prefs later.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier() : super(const SettingsModel());

  void setCurrency(String currency) {
    state = state.copyWith(currency: currency);
  }

  void setSmartInsightsEnabled(bool value) {
    state = state.copyWith(smartInsightsEnabled: value);
  }

  void setMonthlyLeakNotificationsEnabled(bool value) {
    state = state.copyWith(monthlyLeakNotificationsEnabled: value);
  }
}

/// Currency used across the app: settings first, else user default. Use in chat/overview.
final effectiveCurrencyProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  final user = ref.watch(currentUserProvider);
  return settings.currency.isNotEmpty ? settings.currency : (user?.currency ?? 'RSD');
});

/// Increment to force rebuild of screens that depend on transaction list (e.g. after clear/demo).
final transactionVersionProvider = StateProvider<int>((ref) => 0);

/// Mock salary config. Replace with backend when needed.
final mockSalaryServiceProvider = Provider<MockSalaryService>((ref) => MockSalaryService());

/// Increment when salary config (dates, income, allocation) changes so UI rebuilds.
final salaryVersionProvider = StateProvider<int>((ref) => 0);

/// Financial rules engine. Pure logic; replace with AI rule engine later.
final financialRulesServiceProvider = Provider<FinancialRulesService>((ref) => FinancialRulesService());

/// True when chat is awaiting user to reply with salary amount (after "Simulate Salary Day").
final pendingSalaryInputProvider = StateProvider<bool>((ref) => false);

/// Current user (null if not signed in). Replace with auth state from Supabase.
final currentUserProvider =
    StateNotifierProvider<AuthStateNotifier, UserModel?>((ref) {
  return AuthStateNotifier(ref.read(mockAuthServiceProvider));
});

class AuthStateNotifier extends StateNotifier<UserModel?> {
  AuthStateNotifier(this._auth) : super(_auth.currentUser);

  final MockAuthService _auth;

  Future<void> signIn() async {
    await _auth.signIn();
    state = _auth.currentUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = null;
  }
}

/// All chat messages (user + assistant). State lives here for chat screen.
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessageModel>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessageModel>> {
  ChatMessagesNotifier() : super([]);

  void add(ChatMessageModel msg) {
    state = [...state, msg];
  }

  void clear() {
    state = [];
  }
}

/// Guided chat controller & conversation state.
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatControllerState>((ref) {
  return ChatController(ref);
});

