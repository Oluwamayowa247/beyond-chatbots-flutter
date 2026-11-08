// PLACEHOLDER: this file is overwritten when you run:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Until then the app runs in "Offline demo" mode, which uses scripted AI
// responses so every pattern still works on stage without Firebase or wifi.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured yet. Run `flutterfire configure`.',
  );
}
