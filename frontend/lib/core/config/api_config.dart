/// Where the Django API lives.
///
/// Defaults to the live server on Render, so the app works anywhere: on
/// mobile data or any Wi-Fi, without the USB cable.
///
/// To use the backend on this PC instead (phone on USB, after
/// `adb reverse tcp:8000 tcp:8000`):
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000/api`
class ApiConfig {
  static const liveUrl = 'https://futsal-finder-api.onrender.com/api';

  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: liveUrl);
}
