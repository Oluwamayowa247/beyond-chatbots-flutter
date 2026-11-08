# Beyond Chatbots: FlutterBytes 2026 demo

The live companion to the talk *Beyond Chatbots: Building Interactive AI
Experiences in Flutter*. It runs as a **Flutter web app in Chrome** (no
emulator), and each pattern is shown inside a phone frame next to the same
story text as the slides.

| Tab | Pattern | Slide code lives in |
|-----|---------|---------------------|
| 01 | Generative UI (`genui` + A2UI) | `lib/patterns/p1_genui/loan_catalog.dart`, `loan_agent.dart` |
| 02 | Structured output (`firebase_ai`) | `lib/patterns/p2_structured/receipt_scanner.dart` |
| 03 | Function calling (`firebase_ai`) | `lib/patterns/p3_functions/voice_actions.dart` |
| 04 | On-device AI (Gemini Nano) | `lib/patterns/p4_on_device/field_assistant.dart` |

## Run it

**For the talk:** double-click **`Start Talk Demo.bat`** in this folder. Keep
its black window open. Chrome opens on its own when the app is ready (1–2 min).
`Start Talk Demo (Offline only).bat` does the same but locks to Offline mode.

**For editing:** in VS Code, open Run and Debug (Ctrl+Shift+D), pick
**DEV: Chrome (debug, hot reload)** from the dropdown, and press F5.

From a terminal:

```powershell
C:\flutter\bin\flutter.bat run -d chrome
```

Use the arrow keys or a presentation clicker (PageUp / PageDown) to move
between patterns.

> `C:\flutter` is a junction to `C:\Users\MAYOWA OLUTUYO\Flutter\flutter`.
> Flutter's native-asset build hooks fail when the SDK path contains a space,
> so always run Flutter through `C:\flutter`. VS Code is already set up for it
> in `.vscode/settings.json`. Optionally, add `C:\flutter\bin` to your PATH.

## Two modes (top-right toggle)

- **Offline:** scripted responses that still go through the real code
  paths (the real GenUI parser and Surface, the same function router, the same
  form fill). It needs no network, so use it on bad conference wifi.
- **Live:** real calls to `gemini-3.8-flash` through Firebase AI Logic. It is
  enabled automatically once Firebase is configured.

### Turn on Live mode

1. Create a Firebase project, then in the console open **AI Logic** and enable
   the **Gemini Developer API**.
2. Generate `lib/firebase_options.dart`:

   ```powershell
   C:\flutter\bin\dart.bat pub global activate flutterfire_cli
   flutterfire configure --platforms=web,android,ios
   ```

3. Restart the app. The **Live** toggle becomes available.
4. For anything public, turn on **App Check**. Never ship an API key in the app.

Change the model without editing code:
`--dart-define=GEMINI_MODEL=gemini-3.7-flash`.
Force offline mode even when Firebase is set up:
`--dart-define=FORCE_DEMO=true` (also available as a VS Code launch config).

## Pattern 04 in the browser

Slide 14 shows ML Kit's Gemini Nano, which is Android-only. On the web, the app
uses **Chrome's built-in Gemini Nano** (the Prompt API) through
`dart:js_interop` (`on_device_model_web.dart`), following the same steps:
check availability, fall back to the cloud, run locally.

- If Chrome reports the model as *downloadable*, a **Download model** button
  appears in the phone. Downloading takes a few minutes and is needed once.
- If the Prompt API isn't available in your Chrome, the app falls back to the
  cloud (Live mode) or the script (Offline mode), and the screen says which
  engine produced the answer.
- To enable it in desktop Chrome, check `chrome://on-device-internals`, and
  if needed turn on `chrome://flags/#prompt-api-for-gemini-nano`.

## Notes for stage

- Use the **release** launch config on stage, since it starts much faster.
- Pattern 02 can also **upload a photo**. The `sample_receipts` folder has
  three (food, transport, bills) that work in both modes. In Live mode any
  photo works.
- Pattern 02 offers **Use sample receipt**. In Live mode the drawn receipt is
  snapshotted to a real PNG and sent to Gemini, the same way a camera photo is.
- Pattern 03 has a mic button. Speech recognition uses the browser's API (in
  Chrome it needs a network connection and mic permission). Typing and the
  suggestion chips always work.
- `sendMoney` always asks for confirmation, and Undo is hidden once money has
  moved, matching the *Trust* card on slide 15.
