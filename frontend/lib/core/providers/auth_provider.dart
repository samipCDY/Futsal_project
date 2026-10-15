import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

/// Derives the signed-in user's role from Supabase's session so the router
/// can decide whether to show the customer, ground owner, or admin module.
/// Supabase persists the session locally and restores it on cold start, so
/// [isLoading] covers the brief window while that restore is in flight.
class AuthProvider extends ChangeNotifier {
  UserRole? _currentRole;
  String? _roleUserId;
  bool _isLoading = true;

  /// Bumped on every auth event so a slow profile fetch for an older event
  /// (e.g. signed-in) can't overwrite the result of a newer one (signed-out).
  int _generation = 0;

  UserRole? get currentRole => _currentRole;
  String? get userId => _roleUserId;
  bool get isLoggedIn => _currentRole != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final auth = Supabase.instance.client.auth;

    await _handleUser(auth.currentSession?.user);
    _isLoading = false;
    notifyListeners();

    auth.onAuthStateChange.listen((data) async {
      // A password-recovery session only exists so NewPasswordScreen can set
      // the new password; don't swap the reset flow out for the home screen.
      final user = data.event == AuthChangeEvent.passwordRecovery ? null : data.session?.user;
      if (await _handleUser(user)) notifyListeners();
    });
  }

  /// Returns whether this call's result was applied (i.e. not superseded).
  Future<bool> _handleUser(User? user) async {
    final generation = ++_generation;

    if (user == null) {
      _currentRole = null;
      _roleUserId = null;
      return true;
    }
    // Token refreshes re-send the same user; no need to refetch the profile.
    if (user.id == _roleUserId && _currentRole != null) return true;

    final role = await _fetchRole(user.id);
    if (generation != _generation) return false;
    _currentRole = role;
    _roleUserId = role == null ? null : user.id;
    return true;
  }

  /// The role comes only from the `profiles` table, which users can read but
  /// not modify (see supabase/migrations). Never fall back to
  /// `user.userMetadata` — users can edit that themselves via updateUser().
  Future<UserRole?> _fetchRole(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return UserRoleApi.fromApiValue(row?['role'] as String?);
    } catch (e) {
      debugPrint('AuthProvider: could not load profile for $userId: $e');
      return null;
    }
  }

  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
