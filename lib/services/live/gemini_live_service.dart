import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Gemini Live (BidiGenerateContent) voice session.
///
/// Microphone audio (16 kHz PCM) is streamed to Gemini over a WebSocket and
/// Gemini's spoken reply (24 kHz PCM) is played back through a native
/// AudioTrack (see MainActivity.kt, channel "com.mxff.ai/pcm").
/// This does not use the phone's speech recogniser, so it works the same way
/// as the ChatGPT voice mode.
const _wsUrl =
    'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

class GeminiLiveService {
  GeminiLiveService({
    required this.apiKey,
    required this.model,
    required this.voice,
    required this.systemInstruction,
    required this.onStatus,
    required this.onUserText,
    required this.onAssistantText,
    required this.onTurnComplete,
    required this.onError,
  });

  final String apiKey;
  final String model;
  final String voice;
  final String systemInstruction;
  final void Function(String status) onStatus;
  final void Function(String text) onUserText;
  final void Function(String text) onAssistantText;
  final void Function() onTurnComplete;
  final void Function(String error) onError;

  static const MethodChannel _pcm = MethodChannel('com.mxff.ai/pcm');
  static const EventChannel _mic = EventChannel('com.mxff.ai/mic');

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _micSub;
  bool _running = false;
  bool _micStarted = false;
  int _micPackets = 0;
  int _serverMessages = 0;

  Future<void> start() async {
    _running = true;
    onStatus('মাইক্রোফোন চালু হচ্ছে…');
    await _pcm.invokeMethod<void>('start', {'rate': 24000});

    onStatus('Gemini Live সংযোগ হচ্ছে…');
    final modelName = model.startsWith('models/') ? model : 'models/$model';
    final ws = WebSocketChannel.connect(
      Uri.parse('$_wsUrl?key=${Uri.encodeQueryComponent(apiKey)}'),
    );
    _ws = ws;

    ws.stream.listen(
      _onMessage,
      onError: (Object e) {
        if (_running) {
          onError('লাইভ সংযোগ ব্যর্থ — API Key ও মডেল চেক করুন ($e)');
        }
        stop();
      },
      onDone: () {
        if (_running) onError('Gemini সংযোগ বন্ধ হয়েছে।');
        stop();
      },
    );

    ws.sink.add(jsonEncode({
      'setup': {
        'model': modelName,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voice},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
      },
    }));
  }

  void _onMessage(dynamic raw) {
    final String text = raw is String ? raw : utf8.decode(raw as List<int>);
    Map<String, dynamic> m;
    try {
      m = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (m.containsKey('setupComplete')) {
      _startMic();
      onStatus('অনলাইন • বাংলায় কথা বলো');
      return;
    }

    _serverMessages++;
    final c = m['serverContent'] as Map<String, dynamic>?;
    if (c == null) {
      onStatus('Gemini বার্তা: ${m.keys.join(', ')}');
      return;
    }

    if (c['interrupted'] == true) {
      _pcm.invokeMethod<void>('flush').catchError((_) {});
    }

    final inT = c['inputTranscription'] as Map<String, dynamic>?;
    final inText = inT?['text'];
    if (inText is String && inText.isNotEmpty) {
      onUserText(inText);
      onStatus('শুনেছি: $inText');
    }

    final outT = c['outputTranscription'] as Map<String, dynamic>?;
    final outText = outT?['text'];
    if (outText is String && outText.isNotEmpty) onAssistantText(outText);

    final turn = c['modelTurn'] as Map<String, dynamic>?;
    final parts = (turn?['parts'] as List?) ?? const [];
    for (final p in parts) {
      final inline = (p as Map)['inlineData'] as Map?;
      final data = inline?['data'];
      if (data is String && data.isNotEmpty) {
        _pcm.invokeMethod<void>('write', {'data': base64Decode(data)}).catchError((_) {});
      }
    }

    if (c['turnComplete'] == true) onTurnComplete();
  }

  /// Mic audio comes from the native AudioRecord (MainActivity.kt, channel
  /// "com.mxff.ai/mic") as 16 kHz 16-bit mono PCM chunks.
  void _startMic() {
    if (_micStarted || !_running) return;
    _micStarted = true;
    _micSub = _mic.receiveBroadcastStream().listen(
      (dynamic data) {
        final ws = _ws;
        if (ws == null || !_running || data is! Uint8List) return;
        _micPackets++;
        if (_micPackets == 1 || _micPackets % 50 == 0) {
          onStatus('মাইক সক্রিয় • পাঠানো হয়েছে: $_micPackets প্যাকেট');
        }
        try {
          ws.sink.add(jsonEncode({
            'realtimeInput': {
              'audio': {
                'mimeType': 'audio/pcm;rate=16000',
                'data': base64Encode(data),
              },
            },
          }));
        } catch (_) {}
      },
      onError: (Object e) {
        onError('মাইক্রোফোন সমস্যা: $e');
      },
    );
  }

  Future<void> stop() async {
    _running = false;
    await _micSub?.cancel();
    _micSub = null;
    _micStarted = false;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    try {
      await _pcm.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}
