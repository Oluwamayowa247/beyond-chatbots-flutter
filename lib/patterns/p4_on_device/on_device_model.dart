// On the web this is Chrome's built-in Gemini Nano (the Prompt API).
// On Android you would use google_mlkit_genai_prompt instead (see slide 14);
// the stub keeps non-web builds compiling and falls back to the cloud.
export 'on_device_model_stub.dart'
    if (dart.library.js_interop) 'on_device_model_web.dart';
