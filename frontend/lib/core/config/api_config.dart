/// Where the Django API lives.
///
/// Defaults to the local dev server. On a phone plugged in over USB, run
/// `adb reverse tcp:8000 tcp:8000` once so the phone's localhost reaches this
/// PC. Point at another server with
/// `flutter run --dart-define=API_BASE_URL=https://example.com/api`.
class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api');
}
