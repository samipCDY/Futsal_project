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

  static UserRole fromApiValue(String value) {
    switch (value) {
      case 'customer':
        return UserRole.customer;
      case 'ground_owner':
        return UserRole.groundOwner;
      case 'admin':
        return UserRole.admin;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }
}
