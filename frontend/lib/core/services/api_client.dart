import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import 'api_exception.dart';

/// Calls the Django API as the signed-in user. Every request carries the
/// Supabase access token, which is how Django knows who's asking.
class ApiClient {
  static const _timeout = Duration(seconds: 15);

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send((headers) => http.get(_uri(path, query), headers: headers));

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send((headers) => http.post(_uri(path, null), headers: headers, body: jsonEncode(body ?? {})));

  static Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send((headers) => http.patch(_uri(path, null), headers: headers, body: jsonEncode(body)));

  static Future<dynamic> delete(String path) =>
      _send((headers) => http.delete(_uri(path, null), headers: headers));

  static Uri _uri(String path, Map<String, String>? query) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  static Future<dynamic> _send(Future<http.Response> Function(Map<String, String> headers) request) async {
    final token = await _accessToken();

    final http.Response response;
    try {
      response = await request({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(_timeout);
    } on Exception {
      throw ApiException("Can't reach the server. Check your internet connection and try again.");
    }

    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_errorMessage(body, response.statusCode), statusCode: response.statusCode);
  }

  /// Supabase refreshes tokens in the background, but a token can still be
  /// stale right after the app wakes up — refresh it first in that case.
  static Future<String> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        session = (await auth.refreshSession()).session;
      } on AuthException {
        session = null;
      }
    }
    if (session == null) throw ApiException('Your session has expired. Please log in again.');
    return session.accessToken;
  }

  static dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null; // e.g. an HTML error page from a crashed server
    }
  }

  /// Pulls the first readable message out of a Django REST Framework error,
  /// which looks like {"detail": "..."} or {"field": ["..."]}.
  static String _errorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      for (final value in [body['detail'], ...body.values]) {
        if (value is String) return value;
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    if (statusCode == 401) return 'Your session has expired. Please log in again.';
    return 'Something went wrong (error $statusCode). Please try again.';
  }
}
