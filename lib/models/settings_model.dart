/// App preferences. Replace with persisted prefs or backend when needed.
class SettingsModel {
  final String currency;
  final bool smartInsightsEnabled;
  final bool monthlyLeakNotificationsEnabled;

  const SettingsModel({
    this.currency = 'RSD',
    this.smartInsightsEnabled = true,
    this.monthlyLeakNotificationsEnabled = true,
  });

  SettingsModel copyWith({
    String? currency,
    bool? smartInsightsEnabled,
    bool? monthlyLeakNotificationsEnabled,
  }) {
    return SettingsModel(
      currency: currency ?? this.currency,
      smartInsightsEnabled: smartInsightsEnabled ?? this.smartInsightsEnabled,
      monthlyLeakNotificationsEnabled:
          monthlyLeakNotificationsEnabled ?? this.monthlyLeakNotificationsEnabled,
    );
  }

  static const List<String> supportedCurrencies = ['RSD', 'EUR', 'USD'];
}
