/// Non-web fallback. Swap in google_mlkit_genai_prompt here for Android.
abstract final class OnDeviceModel {
  static const engineName = 'Gemini Nano';

  /// One of: unavailable, downloadable, downloading, available.
  static Future<String> availability() async => 'unavailable';

  static Future<void> download({void Function(double)? onProgress}) async {
    throw UnsupportedError('On-device model not available on this platform');
  }

  static Future<String> prompt({
    required String system,
    required String input,
    required Map<String, Object?> schema,
  }) async {
    throw UnsupportedError('On-device model not available on this platform');
  }
}
