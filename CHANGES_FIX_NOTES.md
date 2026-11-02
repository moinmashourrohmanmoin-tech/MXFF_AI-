# MXFF AI - fix notes (only these areas changed)

1. Voice input (lib/state/assistant_provider.dart, lib/services/speech/speech_service.dart)
   - If the final speech result does not arrive, the last recognised text is sent after a 1.5 s pause, or when the engine reports done/error. Sent only once.
   - Callbacks are set before listening starts.
   - Bengali error messages for no-match / timeout / network.

2. Voice output (lib/services/tts/tts_service.dart)
   - If bn-BD is not installed, uses any Bengali voice, then falls back to en-US instead of staying silent.
   - Logs the language used.

3. Bengali commands (lib/core/command_parser.dart)
   - Replaced ASCII \b with Unicode letter lookarounds, so Bengali keywords match.

4. Hide Floating Orb (assistant_provider.dart, android_bridge.dart, MainActivity.kt, MxffOverlayService.kt, AndroidManifest.xml)
   - When the user hides the orb, a persistent notification appears: tap opens MXFF AI; "Orb দেখাও" shows the orb again.
   - Sleep does not show the notification.
   - Showing the orb cancels the notification.
   - POST_NOTIFICATIONS permission added and requested at runtime.

5. permission_service.dart
   - openAppSettings() called itself forever (infinite recursion). Fixed.

NOT changed: UI, Gemini logic, chat storage, other features.
Not yet done: background voice listening when MXFF is minimised (needs a foreground service with microphone type).

## Latest fixes (v4)
- lib/core/command_parser.dart: open-app commands now accept typos and romanised words (opne, kholo, koro, করো). "tiktok opne" opens TikTok.
- lib/core/constants.dart: Messages app added (Google Messages + Samsung Messages). More aliases for TikTok and YouTube. System prompt no longer tells the user the app cannot open apps.
- MainActivity.kt: openApp and isAppInstalled accept several package names separated by commas.
- .github/workflows/build-apk.yml: APK build workflow included.

## v5
- lib/services/speech/speech_service.dart: the settings locale "bn-BD" (hyphen) is now matched against the locales the phone really has ("bn_BD", "bn_IN", ...). If none exists, English or the device default is used. This is the likely reason voice was not heard.

## v6
- android/app/src/main/AndroidManifest.xml: added <queries> for android.speech.RecognitionService and android.intent.action.TTS_SERVICE. On Android 11+ without these, the app cannot see the phone's speech recogniser or TTS engine, so voice input and voice output stay silent while other apps (ChatGPT) work.
