import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech with configurable rate / pitch / volume and language.
/// Completion + start handlers are exposed so UI can show speaking state.
///
/// If the device has no voice for the requested language (common for Bengali),
/// we look for any Bengali voice, then fall back to English, instead of
/// silently speaking nothing.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  /// The language actually in use after configure() (may differ from request).
  String activeLanguage = '';

  /// True when the requested language was not available on this device.
  bool languageFallback = false;

  void Function()? onStart;
  void Function()? onComplete;
  void Function()? onError;

  TtsService() {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((msg) {
      debugPrint('MXFF TTS error: $msg');
      onError?.call();
    });
  }

  Future<void> configure({
    required String locale,
    required double rate,
    required double volume,
    required double pitch,
  }) async {
    activeLanguage = await _pickLanguage(locale);
    await _tts.setSpeechRate(rate);
    await _tts.setVolume(volume.clamp(0.0, 1.0));
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  bool get isConfigured => _configured;

  /// Returns the language code that was actually set.
  Future<String> _pickLanguage(String wanted) async {
    languageFallback = false;
    if (wanted.isEmpty) return ''; // device default, nothing to choose
    if (await _trySetLanguage(wanted)) {
      debugPrint('MXFF TTS language: $wanted');
      return wanted;
    }

    // Requested language missing: try any installed voice that starts with the
    // same language prefix (e.g. 'bn' -> bn-IN, bn-BD).
    final prefix = wanted.split(RegExp(r'[-_]')).first.toLowerCase();
    if (prefix.isNotEmpty) {
      final voice = await _findVoiceForPrefix(prefix);
      if (voice != null) {
        final ok = await _tts.setVoice(voice);
        if (_ok(ok)) {
          languageFallback = true;
          debugPrint('MXFF TTS using voice ${voice['name']} (${voice['locale']})');
          return voice['locale'] ?? prefix;
        }
      }
    }

    // Last resort: English so the user still hears something.
    for (final lang in const ['en-US', 'en-GB']) {
      if (await _trySetLanguage(lang)) {
        languageFallback = true;
        debugPrint('MXFF TTS fallback to $lang (requested "$wanted")');
        return lang;
      }
    }
    debugPrint('MXFF TTS: no usable language found, using device default');
    return '';
  }

  Future<bool> _trySetLanguage(String lang) async {
    try {
      final available = await _tts.isLanguageAvailable(lang);
      if (!_ok(available)) return false;
      return _ok(await _tts.setLanguage(lang));
    } catch (e) {
      debugPrint('MXFF TTS setLanguage($lang) failed: $e');
      return false;
    }
  }

  Future<Map<String, String>?> _findVoiceForPrefix(String prefix) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return null;
      for (final v in voices) {
        if (v is! Map) continue;
        final locale = (v['locale'] ?? '').toString();
        final name = (v['name'] ?? '').toString();
        if (locale.toLowerCase().startsWith(prefix)) {
          return {'name': name, 'locale': locale};
        }
      }
    } catch (e) {
      debugPrint('MXFF TTS getVoices failed: $e');
    }
    return null;
  }

  /// flutter_tts returns 1/true on success and 0/false/other on failure.
  bool _ok(dynamic r) => r == 1 || r == true || r == '1';

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    debugPrint('MXFF TTS speak (${activeLanguage.isEmpty ? 'default' : activeLanguage}): ${text.length} chars');
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}
