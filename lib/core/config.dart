/// The Gemini model used by every cloud call in the demo.
///
/// Override without editing code:
///   flutter run -d chrome --dart-define=GEMINI_MODEL=gemini-3.7-flash
const String kGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.8-flash',
);

/// Force the scripted offline mode even when Firebase is configured.
/// Handy on conference wifi:  --dart-define=FORCE_DEMO=true
const bool kForceDemo = bool.fromEnvironment('FORCE_DEMO');
