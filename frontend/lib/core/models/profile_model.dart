/// The signed-in user's own profile and app preferences.
class ProfileModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName; // "first last", kept in step by the API
  final DateTime? dateOfBirth;
  final String? gender; // "male", "female", "other", or null
  final String mobileNumber;
  final String address;
  final String city;
  final String avatarUrl; // empty when there's no photo
  final String role;
  final Preferences preferences;

  const ProfileModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    required this.mobileNumber,
    required this.address,
    required this.city,
    required this.avatarUrl,
    required this.role,
    required this.preferences,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final dateOfBirth = json['date_of_birth'] as String?;
    return ProfileModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      dateOfBirth: dateOfBirth == null ? null : DateTime.parse(dateOfBirth),
      gender: json['gender'] as String?,
      mobileNumber: json['mobile_number'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      role: json['role'] as String,
      preferences: Preferences.fromJson(json['preferences'] as Map<String, dynamic>),
    );
  }

  ProfileModel copyWith({Preferences? preferences}) => ProfileModel(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        mobileNumber: mobileNumber,
        address: address,
        city: city,
        avatarUrl: avatarUrl,
        role: role,
        preferences: preferences ?? this.preferences,
      );

  /// "Samip" + "Chaudhary" -> "SC"
  String get initials {
    final letters = [firstName, lastName].map((n) => n.trim()).where((n) => n.isNotEmpty).map((n) => n[0]);
    return letters.isEmpty ? '?' : letters.join().toUpperCase();
  }
}

class Preferences {
  final String theme; // "system", "light" or "dark"
  final String language; // "en" or "ne"
  final bool notificationsEnabled;

  const Preferences({required this.theme, required this.language, required this.notificationsEnabled});

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String,
        language: json['language'] as String,
        notificationsEnabled: json['notifications_enabled'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'language': language,
        'notifications_enabled': notificationsEnabled,
      };

  Preferences copyWith({String? theme, String? language, bool? notificationsEnabled}) => Preferences(
        theme: theme ?? this.theme,
        language: language ?? this.language,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}
