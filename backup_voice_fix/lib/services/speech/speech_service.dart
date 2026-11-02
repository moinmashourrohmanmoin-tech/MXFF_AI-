import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Speech-to-text service. Supports one-shot listening (with a callback for
/// partial + final results) and continuous re-listen loops for "listening
/// mode" while the app stays open.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _continuous = false;
  String _locale = '';

  bool get isListening => _speech.isListening;
  bool get isInitialized => _initialized;

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) {
        debugPrint('MXFF speech status: $status');
        onStatusChange?.call(status);
        if (status == 'done' || status == 'notListening') {
          if (_continuous) _restartLoop();
        }
      },
      onError: (error) {
        debugPrint('MXFF speech error: ${error.errorMsg}');
        onErrorChange?.call(error.errorMsg);
        if (_continuous) _restartLoop();
      },
    );
    return _initialized;
  }

  void _restartLoop() {
    if (!_continuous) return;
    Future.delayed(const Duration(milliseconds: 250), () async {
      if (!_continuous || _speech.isListening) return;
      try {
        await _speech.listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
            listenMode: ListenMode.confirmation,
            localeId: _locale.isEmpty ? null : _locale,
          ),
        );
      } catch (_) {}
    });
  }

  void Function(String text, bool finalResult)? onResult;

  /// Called with raw engine status strings ('listening', 'notListening', 'done').
  void Function(String status)? onStatusChange;

  /// Called with the engine error message (e.g. 'error_no_match').
  void Function(String errorMsg)? onErrorChange;

  void _onResult(SpeechRecognitionResult r) {
    debugPrint('MXFF speech result (final=${r.finalResult}): ${r.recognizedWords}');
    onResult?.call(r.recognizedWords, r.finalResult);
  }

  /// Picks a locale the device's recogniser really supports.
  /// Android expects ids like "bn_BD" (underscore); settings may hold "bn-BD".
  /// Falls back to any Bengali locale, then English, then the device default.
  Future<String> _resolveLocale(String wanted) async {
    if (wanted.isEmpty) return '';
    try {
      final locales = await _speech.locales();
      String norm(String x) => x.replaceAll('-', '_').toLowerCase();
      final names = locales.map((l) => l.localeId).toList();
      debugPrint('MXFF available speech locales: ${names.join(', ')}');
      final want = norm(wanted);
      for (final id in names) {
        if (norm(id) == want) return id;
      }
      final prefix = want.split('_').first;
      for (final id in names) {
        if (norm(id).startsWith('${prefix}_')) return id;
      }
      for (final id in names) {
        if (norm(id) == 'en_us') return id;
      }
    } catch (e) {
      debugPrint('MXFF locale lookup failed: $e');
    }
    return '';
  }

  /// Locale actually used by the last listen (for on-screen diagnostics).
  String get activeLocale => _locale.isEmpty ? 'device default' : _locale;

  /// One-shot listen. Returns recognized text via [onResult].
  Future<void> listenOnce({required String locale}) async {
    _continuous = false;
    if (!await init()) {
      throw Exception('speech_unavailable');
    }
    locale = await _resolveLocale(locale);
    debugPrint('MXFF listening with locale: ${locale.isEmpty ? 'device default' : locale}');
    _locale = locale;
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
        localeId: locale.isEmpty ? null : locale,
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  /// Continuous listening loop (app must remain in the foreground).
  Future<void> startContinuous({required String locale}) async {
    if (!await init()) throw Exception('speech_unavailable');
    locale = await _resolveLocale(locale);
    _locale = locale;
    _continuous = true;
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.confirmation,
        localeId: locale.isEmpty ? null : locale,
      ),
    );
  }

  Future<void> stop() async {
    _continuous = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> dispose() => stop();
}
