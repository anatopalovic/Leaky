/// User model. Replace with real user from Supabase when integrating auth.
class UserModel {
  final String id;
  final String? email;
  final String currency;
  final int monthlyIncome;

  const UserModel({
    required this.id,
    this.email,
    required this.currency,
    required this.monthlyIncome,
  });

  /// Mock user used when "logging in". Replace with Supabase session user.
  static const UserModel mock = UserModel(
    id: 'mock_user_1',
    email: 'user@example.com',
    currency: 'RSD',
    monthlyIncome: 120000,
  );
}
