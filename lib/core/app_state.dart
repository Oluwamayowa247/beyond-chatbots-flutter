import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'config.dart';

/// Where AI answers come from.
enum AiMode {
  /// Real Gemini calls through Firebase AI Logic.
  live,

  /// Scripted responses that run through the same code paths. No network.
  demo,
}

/// Tiny global state for the demo. Deliberately simple: this is a talk demo,
/// not an architecture lesson.
class AppState {
  AppState._();

  static bool firebaseReady = false;
  static String? firebaseError;

  /// Live when Firebase is configured, otherwise the offline demo.
  static final ValueNotifier<AiMode> mode = ValueNotifier(AiMode.demo);

  static bool get isLive => mode.value == AiMode.live;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    } catch (e) {
      firebaseReady = false;
      firebaseError = '$e';
      debugPrint('Firebase not ready, using offline demo mode: $e');
    }
    mode.value = firebaseReady && !kForceDemo ? AiMode.live : AiMode.demo;
  }
}
