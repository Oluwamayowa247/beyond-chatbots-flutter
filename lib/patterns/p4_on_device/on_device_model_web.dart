import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Chrome's built-in Gemini Nano via the Prompt API (`LanguageModel`).
/// Everything runs inside the browser: no network, no per-call cost.
abstract final class OnDeviceModel {
  static const engineName = 'Gemini Nano in Chrome';

  static bool get _supported => globalContext.has('LanguageModel');

  static JSObject get _lm =>
      globalContext.getProperty<JSObject>('LanguageModel'.toJS);

  static Map<String, Object?> get _languageOptions => {
    'expectedInputs': [
      {
        'type': 'text',
        'languages': ['en'],
      },
    ],
    'expectedOutputs': [
      {
        'type': 'text',
        'languages': ['en'],
      },
    ],
  };

  /// One of: unavailable, downloadable, downloading, available.
  static Future<String> availability() async {
    if (!_supported) return 'unavailable';
    try {
      final result = await _lm
          .callMethod<JSPromise<JSString>>(
            'availability'.toJS,
            _languageOptions.jsify(),
          )
          .toDart;
      return result.toDart;
    } catch (_) {
      return 'unavailable';
    }
  }

  /// Downloads the model. Must be called from a user gesture (a tap).
  static Future<void> download({void Function(double)? onProgress}) async {
    final session = await _create(onProgress: onProgress);
    session.callMethod<JSAny?>('destroy'.toJS);
  }

  static Future<JSObject> _create({
    String? system,
    void Function(double)? onProgress,
  }) {
    final options =
        <String, Object?>{
              ..._languageOptions,
              if (system != null)
                'initialPrompts': [
                  {'role': 'system', 'content': system},
                ],
            }.jsify()!
            as JSObject;
    if (onProgress != null) {
      options['monitor'] = ((JSObject monitor) {
        monitor.callMethod<JSAny?>(
          'addEventListener'.toJS,
          'downloadprogress'.toJS,
          ((JSObject e) {
            final loaded = e['loaded'];
            if (loaded.isA<JSNumber>()) {
              onProgress((loaded as JSNumber).toDartDouble);
            }
          }).toJS,
        );
      }).toJS;
    }
    return _lm.callMethod<JSPromise<JSObject>>('create'.toJS, options).toDart;
  }

  /// Runs one prompt locally, constrained to a JSON schema.
  static Future<String> prompt({
    required String system,
    required String input,
    required Map<String, Object?> schema,
  }) async {
    final session = await _create(system: system);
    try {
      final result = await session
          .callMethod<JSPromise<JSString>>(
            'prompt'.toJS,
            input.toJS,
            {'responseConstraint': schema}.jsify(),
          )
          .toDart;
      return result.toDart;
    } finally {
      session.callMethod<JSAny?>('destroy'.toJS);
    }
  }
}
