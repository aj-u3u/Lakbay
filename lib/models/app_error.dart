/// Standardized error types for the Lakbay+ app.
///
/// Use [AppError] to represent any recoverable or displayable error.
/// The [ErrorState] widget knows how to render each type with the correct
/// user-facing message, icon, and action button.
///
/// Example:
/// ```dart
/// throw AppError(AppErrorType.noInternet);
/// throw AppError(AppErrorType.aiUnavailable);
/// throw AppError(AppErrorType.sessionExpired);
/// ```
enum AppErrorType {
  /// Device has no active internet connection.
  noInternet,

  /// The Gemini / AI service returned an error or timed out.
  aiUnavailable,

  /// A photo or file upload failed (e.g. file too large, network error).
  uploadFailed,

  /// A required form field is empty or invalid.
  missingInput,

  /// The user's auth session has expired and they need to log in again.
  sessionExpired,

  /// A generic / unknown error not covered by the specific types above.
  generic,
}

/// Represents an application-level error with a typed category and optional
/// debug detail that is never shown to the user.
class AppError implements Exception {
  final AppErrorType type;

  /// Developer-facing detail (stack trace snippet, API message, etc.).
  /// Never displayed in the UI.
  final String? debugDetail;

  const AppError(this.type, {this.debugDetail});

  /// The user-facing message for this error type.
  String get userMessage {
    switch (type) {
      case AppErrorType.noInternet:
        return 'No connection. Check your network and try again.';
      case AppErrorType.aiUnavailable:
        return 'AI is temporarily unavailable. Try again shortly.';
      case AppErrorType.uploadFailed:
        return 'Upload failed. Please try a smaller image.';
      case AppErrorType.missingInput:
        return 'Please fill in all required fields.';
      case AppErrorType.sessionExpired:
        return 'Your session has expired. Please log in again.';
      case AppErrorType.generic:
        return 'Something went wrong. Please try again.';
    }
  }

  /// The label for the primary action button.
  String get actionLabel {
    switch (type) {
      case AppErrorType.noInternet:
      case AppErrorType.aiUnavailable:
      case AppErrorType.generic:
        return 'Retry';
      case AppErrorType.uploadFailed:
        return 'Try Again';
      case AppErrorType.missingInput:
        return 'Review Fields';
      case AppErrorType.sessionExpired:
        return 'Log In';
    }
  }

  @override
  String toString() =>
      'AppError(${type.name}${debugDetail != null ? ': $debugDetail' : ''})';
}
