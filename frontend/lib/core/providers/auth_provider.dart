import 'package:flutter/foundation.dart';
import '../models/user_role.dart';

/// Holds the signed-in user's role so the router can decide whether to show
/// the customer, ground owner, or admin module. No real authentication yet —
/// this is wired up once the backend exists.
class AuthProvider extends ChangeNotifier {
  UserRole? _currentRole;

  UserRole? get currentRole => _currentRole;
  bool get isLoggedIn => _currentRole != null;

  void signInAs(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void signOut() {
    _currentRole = null;
    notifyListeners();
  }
}
