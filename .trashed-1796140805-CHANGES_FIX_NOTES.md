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
