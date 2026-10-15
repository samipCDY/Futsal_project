/// A failure with a message that's safe to show the user as-is.
class ApiException implements Exception {
  final String message;

  /// The HTTP status from the Django API, when the error came from there.
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
