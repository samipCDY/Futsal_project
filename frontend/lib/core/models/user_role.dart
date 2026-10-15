/// The three account types supported by the app. Drives which
/// feature module (customer/owner/admin) the router loads after login.
enum UserRole { customer, groundOwner, admin }

extension UserRoleApi on UserRole {
  /// Matches the string values in the Django `User.Role` choices.
  String get apiValue {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.groundOwner:
        return 'ground_owner';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Returns null for anything unrecognised, so a bad value in the database
  /// can't crash the auth listener — the user just isn't let in.
  static UserRole? fromApiValue(String? value) {
    switch (value) {
      case 'customer':
        return UserRole.customer;
      case 'ground_owner':
        return UserRole.groundOwner;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }
}
