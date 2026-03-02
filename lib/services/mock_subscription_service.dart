/// Mock subscription. Replace with RevenueCat (or similar) when integrating real IAP.
/// Premium state is held in SubscriptionStatusNotifier (Riverpod); upgrade/restore are mocked here.
class MockSubscriptionService {
  /// Mock upgrade. Replace with RevenueCat purchase flow.
  /// Caller (SubscriptionNotifier) updates state after this.
  void upgradeToPremium() {
    // No-op here; notifier sets isPremium = true.
  }

  /// Mock restore. In real app would call RevenueCat restore and sync state.
  void restorePurchases() {
    // No state change for mock; UI shows "Purchases restored (mocked)" dialog.
  }
}
