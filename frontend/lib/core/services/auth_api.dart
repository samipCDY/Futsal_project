import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_role.dart';

/// Base URL for the Django backend. `localhost` works for both the Chrome
/// build (same machine) and a physical Android device connected via USB —
/// on the phone, run `adb reverse tcp:8000 tcp:8000` once so its own
/// localhost:8000 forwards to this PC's Django server over the USB link.
class ApiConfig {
  static const baseUrl = 'http://localhost:8000/api';
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class AuthResult {
  final String email;
  final String fullName;
  final String mobileNumber;
  final UserRole role;

  AuthResult({
    required this.email,
    required this.fullName,
    required this.mobileNumber,
    required this.role,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      role: UserRoleApi.fromApiValue(json['role'] as String),
    );
  }
}

class AuthApi {
  static Future<void> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accounts/otp/send/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractDetail(response.body) ?? 'Could not send verification code.');
    }
  }

  static Future<void> verifyOtp(String email, String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accounts/otp/verify/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractDetail(response.body) ?? 'Verification failed.');
    }
  }

  static Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    required String mobileNumber,
    required UserRole role,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accounts/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'mobile_number': mobileNumber,
        'role': role.apiValue,
      }),
    );
    if (response.statusCode != 201) {
      throw ApiException(_extractDetail(response.body) ?? 'Could not create your account.');
    }
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accounts/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractDetail(response.body) ?? 'Login failed.');
    }
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> resetPassword(String email, String newPassword) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accounts/reset-password/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'new_password': newPassword}),
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractDetail(response.body) ?? 'Could not reset your password.');
    }
  }

  static String? _extractDetail(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail'] as String?;
    } catch (_) {
      return null;
    }
  }
}
