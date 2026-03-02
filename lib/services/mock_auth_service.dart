import '../models/user_model.dart';

/// Mock auth. Replace with SupabaseAuthService / Firebase when ready.
/// signIn() / signOut() / currentUser are the contract to keep.
class MockAuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  /// Simulates sign in. No real API. Replace with Supabase signIn later.
  Future<void> signIn() async {
    _currentUser = UserModel.mock;
  }

  /// Simulates sign out. Replace with Supabase signOut later.
  Future<void> signOut() async {
    _currentUser = null;
  }

  /// Check if user is logged in (for navigation).
  bool get isSignedIn => _currentUser != null;
}
