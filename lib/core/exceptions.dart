/// User-presentable app errors. `message` is always safe to show in the UI.
class MxffException implements Exception {
  final String message;
  final bool retryable;

  /// True when the error is about the selected Gemini model not being
  /// available for the user's key (404 / "model not found" style errors),
  /// which triggers the automatic model fallback.
  final bool modelUnavailable;
  const MxffException(this.message,
      {this.retryable = false, this.modelUnavailable = false});

  @override
  String toString() => message;
}
