import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/command_parser.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../data/models/chat_message.dart';
import '../services/live/gemini_live_service.dart';
import 'providers.dart';

enum AssistantStatus { idle, listening, thinking, speaking, error, sleeping }

class AssistantState {
  final AssistantStatus status;
  final String statusText;
  final String lastFailedPrompt;
  final bool listeningMode;
  final bool overlayVisible;

  const AssistantState({
    this.status = AssistantStatus.idle,
    this.statusText = 'Ready',
    this.lastFailedPrompt = '',
    this.listeningMode = false,
    this.overlayVisible = false,
  });

  bool get busy => status == AssistantStatus.thinking;

  AssistantState copyWith({
    AssistantStatus? status,
    String? statusText,
    String? lastFailedPrompt,
    bool? listeningMode,
    bool? overlayVisible,
  }) =>
      AssistantState(
        status: status ?? this.status,
        statusText: statusText ?? this.statusText,
        lastFailedPrompt: lastFailedPrompt ?? this.lastFailedPrompt,
        listeningMode: listeningMode ?? this.listeningMode,
        overlayVisible: overlayVisible ?? this.overlayVisible,
      );
}

/// Central assistant controller: chat flow, voice flow, phone actions,
/// overlay control, sleep / wake.
class AssistantNotifier extends Notifier<AssistantState> {
  bool _alive = true;

  @override
  AssistantState build() {
    ref.onDispose(() => _alive = false);
    return const AssistantState();
  }

  SettingsNotifier get _settings => ref.read(settingsProvider.notifier);
  ChatNotifier get _chat => ref.read(chatProvider.notifier);

  // ------------------------------------------------------------------
  // Chat / voice send flow
  // ------------------------------------------------------------------
  Future<void> send(String raw, {bool speakAnswer = true}) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (state.status == AssistantStatus.sleeping) return;
    if (state.busy) return;

    // 1) Device commands (offline, rule-based).
    final action = CommandParser.parse(text);
    if (action != null) {
      _chat.addUserMessage(text);
      await _runAction(action, speakIt: true);
      return;
    }

    // 2) Gemini conversation.
    _chat.addUserMessage(text);
    _chat.ensureActiveConversation(text);
    await _askGemini(text, speakAnswer: speakAnswer);
  }

  Future<void> _askGemini(String prompt, {required bool speakAnswer}) async {
    final gemini = ref.read(geminiServiceProvider);
    final tts = ref.read(ttsServiceProvider);

    await tts.stop(); // interrupt any ongoing speech
    _setStatus(AssistantStatus.thinking, 'Thinking…');

    final history = (ref.read(chatProvider).active?.messages ?? [])
        .where((m) => !m.failed && (m.role == 'user' || m.role == 'model'))
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    if (history.isNotEmpty) history.removeLast(); // prompt sent separately

    final settings = ref.read(settingsProvider);
    try {
      final answer = await gemini.ask(
        apiKey: settings.geminiApiKey,
        model: settings.model,
        systemInstruction: settings.systemInstruction,
        history: history,
        prompt: prompt,
      );
      // Persist the model that actually worked (auto-detected or fallback),
      // so the next message reuses it instead of failing again.
      final currentModel = ref.read(settingsProvider).model;
      if (answer.modelUsed.isNotEmpty && answer.modelUsed != currentModel) {
        await _settings.update((s) => s.copyWith(model: answer.modelUsed));
      }
      _chat.addModelMessage(answer.text);
      _setStatus(AssistantStatus.speaking, 'Speaking…');
      if (speakAnswer) {
        await _configureTts();
        await tts.speak(answer.text);
      }
      if (_alive &&
          ref.read(assistantProvider).status == AssistantStatus.speaking) {
        _setStatus(AssistantStatus.idle, 'Ready');
      }
      _syncOverlayStatus();
    } on MxffException catch (e) {
      _chat.addModelMessage(e.message, failed: true);
      _setStatus(AssistantStatus.error, e.message);
      _syncOverlayStatus();
    } catch (e) {
      const msg = 'অপ্রত্যাশিত সমস্যা হয়েছে। আবার চেষ্টা করুন।';
      _chat.addModelMessage(msg, failed: true);
      _setStatus(AssistantStatus.error, msg);
      _syncOverlayStatus();
    }
  }

  Future<void> retryLastFailed() async {
    final messages = ref.read(chatProvider).active?.messages ?? [];
    final empty = ChatMessage(
        id: '', role: 'user', text: '', time: DateTime.fromMillisecondsSinceEpoch(0));
    final lastUser = messages.lastWhere((m) => m.isUser, orElse: () => empty);
    if (lastUser.text.isEmpty) return;
    // Remove the failed message, then ask again.
    _chat.removeLastModelMessage();
    await _askGemini(lastUser.text, speakAnswer: true);
  }

  Future<void> _configureTts() async {
    final settings = ref.read(settingsProvider);
    final tts = ref.read(ttsServiceProvider);
    await tts.configure(
      locale: settings.speechLocale,
      rate: settings.speechRate,
      volume: settings.ttsVolume,
      pitch: settings.ttsPitch,
    );
  }

  // ------------------------------------------------------------------
  // Microphone
  // ------------------------------------------------------------------
  // Voice capture state for one-shot mic input.
  String _lastPartial = '';
  bool _voiceSent = false;
  Timer? _voiceFlushTimer;
  String _lastEngineEvent = '';

  GeminiLiveService? _live;
  String _liveUserBuf = '';
  String _liveModelBuf = '';

  /// Starts or stops a Gemini Live voice session.
  Future<void> toggleLive() async {
    if (_live != null) {
      await stopLive();
      return;
    }
    final settings = ref.read(settingsProvider);
    final key = settings.geminiApiKey.trim();
    if (key.isEmpty) {
      _setStatus(AssistantStatus.error, 'প্রথমে Settings-এ Gemini API key দিন।');
      return;
    }
    if (state.status == AssistantStatus.speaking) {
      await stopSpeaking();
    }
    _liveUserBuf = '';
    _liveModelBuf = '';
    final live = GeminiLiveService(
      apiKey: key,
      model: kLiveModel,
      voice: kLiveVoice,
      systemInstruction: settings.systemInstruction,
      onStatus: (s) => _setStatus(AssistantStatus.listening, s),
      onUserText: (t) => _liveUserBuf += t,
      onAssistantText: (t) => _liveModelBuf += t,
      onTurnComplete: _flushLiveTurn,
      onError: (e) {
        debugPrint('MXFF live error: $e');
        _setStatus(AssistantStatus.error, e);
        stopLive();
      },
    );
    _live = live;
    _setStatus(AssistantStatus.listening, 'Live চালু হচ্ছে…');
    await live.start();
  }

  void _flushLiveTurn() {
    final u = _liveUserBuf.trim();
    final m = _liveModelBuf.trim();
    if (u.isNotEmpty) _chat.addUserMessage(u);
    if (m.isNotEmpty) _chat.addModelMessage(m);
    _liveUserBuf = '';
    _liveModelBuf = '';
  }

  Future<void> stopLive() async {
    final live = _live;
    _live = null;
    if (live != null) {
      _flushLiveTurn();
      await live.stop();
    }
    _setStatus(AssistantStatus.idle, 'Ready');
  }

  Future<void> toggleMic() async {
    if (kUseGeminiLive) {
      await toggleLive();
      return;
    }
    if (state.status == AssistantStatus.listening) {
      await stopListening();
      return;
    }
    if (state.status == AssistantStatus.speaking) {
      await stopSpeaking(); // interrupt response, then listen
    }
    final permissions = ref.read(permissionServiceProvider);
    final mic = await permissions.requestMicrophone();
    if (mic == null) {
      _setStatus(AssistantStatus.error,
          'মাইক্রোফোন অনুমতি পার্মানেন্টলি বন্ধ। App settings থেকে চালু করুন।');
      return;
    }
    if (!mic) {
      _setStatus(AssistantStatus.error, 'মাইক্রোফোন অনুমতি দরকার ভয়েসের জন্য।');
      return;
    }
    final speech = ref.read(speechServiceProvider);
    final settings = ref.read(settingsProvider);

    // Reset capture state for this utterance.
    _lastPartial = '';
    _voiceSent = false;
    _lastEngineEvent = '';
    _voiceFlushTimer?.cancel();

    // Callbacks must be set BEFORE listening starts.
    speech.onResult = (text, finalResult) {
      debugPrint('MXFF voice result final=$finalResult text=$text');
      if (_voiceSent) return;
      final t = text.trim();
      if (t.isNotEmpty) _lastPartial = t;
      if (finalResult) {
        _sendVoice();
        return;
      }
      // Some Android devices never deliver a final result. If speech pauses
      // for a moment, send the last recognised text ourselves.
      _voiceFlushTimer?.cancel();
      _voiceFlushTimer =
          Timer(const Duration(milliseconds: 1500), () => _sendVoice());
    };
    speech.onStatusChange = (status) {
      _lastEngineEvent = 'status:$status';
      if (status == 'done' || status == 'notListening') _sendVoice();
    };
    speech.onErrorChange = (msg) {
      debugPrint('MXFF voice error: $msg');
      _lastEngineEvent = 'error:$msg';
      if (state.status != AssistantStatus.listening) return;
      if (_lastPartial.isNotEmpty) {
        _sendVoice();
        return;
      }
      _voiceFlushTimer?.cancel();
      _setStatus(AssistantStatus.idle, _voiceErrorText(msg));
    };

    _setStatus(AssistantStatus.listening, 'Listening… এখন বলুন…');
    try {
      await speech.listenOnce(locale: settings.speechLocale);
    } catch (e) {
      debugPrint('MXFF listenOnce failed: $e');
      _setStatus(AssistantStatus.error,
          'এই ডিভাইসে স্পিচ রিকগনিশন পাওয়া যাচ্ছে না।');
    }
  }

  /// Sends the captured voice text exactly once.
  void _sendVoice() {
    _voiceFlushTimer?.cancel();
    if (_voiceSent) return;
    if (state.status != AssistantStatus.listening) return;
    final text = _lastPartial.trim();
    _voiceSent = true;
    ref.read(speechServiceProvider).stop();
    if (text.isEmpty) {
      final loc = ref.read(speechServiceProvider).activeLocale;
      _setStatus(AssistantStatus.idle,
          'কিছু শোনা যায়নি। (locale: $loc, event: $_lastEngineEvent)');
      return;
    }
    debugPrint('MXFF sending voice text: $text');
    _setStatus(AssistantStatus.idle, 'Ready');
    send(text);
  }

  String _voiceErrorText(String msg) {
    switch (msg) {
      case 'error_no_match':
        return 'কথাটা বোঝা যায়নি, আবার বলুন।';
      case 'error_speech_timeout':
      case 'error_no_speech':
        return 'কিছু শোনা যায়নি, আবার মাইক চাপুন।';
      case 'error_network':
      case 'error_network_timeout':
        return 'ভয়েসের জন্য ইন্টারনেট দরকার, সংযোগ চেক করুন।';
      case 'error_permission':
        return 'মাইক্রোফোন অনুমতি নেই।';
      default:
        return 'ভয়েস সমস্যা হয়েছে ($msg)। আবার চেষ্টা করুন।';
    }
  }

  Future<void> stopListening() async {
    _voiceFlushTimer?.cancel();
    await ref.read(speechServiceProvider).stop();
    if (state.status == AssistantStatus.listening) {
      _setStatus(AssistantStatus.idle, 'Ready');
    }
  }

  /// "Listening mode": continuous recognition while MXFF AI stays open.
  /// Text that contains the wake phrase is forwarded to the assistant.
  Future<void> toggleListeningMode() async {
    if (state.listeningMode) {
      await ref.read(speechServiceProvider).stop();
      state = state.copyWith(listeningMode: false);
      if (state.status == AssistantStatus.listening) {
        _setStatus(AssistantStatus.idle, 'Ready');
      }
      return;
    }
    final permissions = ref.read(permissionServiceProvider);
    if (!await permissions.requestMicrophone().then((v) => v == true)) {
      _setStatus(AssistantStatus.error, 'মাইক্রোফোন অনুমতি দরকার।');
      return;
    }
    final speech = ref.read(speechServiceProvider);
    final settings = ref.read(settingsProvider);
    try {
      await speech.startContinuous(locale: settings.speechLocale);
      speech.onResult = (text, finalResult) => _onContinuousResult(text, finalResult);
      state = state.copyWith(listeningMode: true);
      _setStatus(AssistantStatus.listening,
          'Listening mode ON — "${settings.wakePhrase}" বললে আমি জেগে উঠবো।');
    } catch (_) {
      _setStatus(AssistantStatus.error, 'স্পিচ রিকগনিশন চালু করা গেল না।');
    }
  }

  void _onContinuousResult(String text, bool finalResult) {
    if (!finalResult) return;
    final phrase = ref.read(settingsProvider).wakePhrase.toLowerCase().trim();
    final lower = text.toLowerCase().trim();
    if (phrase.isNotEmpty && lower.contains(phrase)) {
      var command = lower
          .replaceAll(phrase, '')
          .replaceAll(RegExp(r'[।,.!?]'), '')
          .trim();
      state = state.copyWith(listeningMode: false);
      ref.read(speechServiceProvider).stop();
      _setStatus(AssistantStatus.idle, 'Ready');
      send(command.isEmpty ? phrase : command);
    }
  }

  // ------------------------------------------------------------------
  // Speaking
  // ------------------------------------------------------------------
  Future<void> stopSpeaking() async {
    await ref.read(ttsServiceProvider).stop();
    if (state.status == AssistantStatus.speaking) {
      _setStatus(AssistantStatus.idle, 'Ready');
    }
    _syncOverlayStatus();
  }

  // ------------------------------------------------------------------
  // Phone actions
  // ------------------------------------------------------------------
  bool requiresConfirmation(DeviceAction a) => a.type == DeviceActionType.sleep;

  Future<void> runAction(DeviceAction action, {bool speakIt = false}) =>
      _runAction(action, speakIt: speakIt);

  Future<void> _runAction(DeviceAction action, {required bool speakIt}) async {
    final bridge = ref.read(androidBridgeProvider);
    final tts = ref.read(ttsServiceProvider);
    String spoken;

    switch (action.type) {
      case DeviceActionType.openApp:
        final ok = await bridge.openApp(action.packageName ?? '');
        spoken = ok ? '${action.label} হচ্ছে।' : '${action.label} — অ্যাপটি পাওয়া যায়নি।';
        _chat.addModelMessage(spoken);
        break;
      case DeviceActionType.minimizeApp:
        await bridge.minimizeApp();
        spoken = 'MXFF AI মিনিমাইজ হলো, floating orb চালু আছে।';
        _chat.addModelMessage(spoken);
        break;
      case DeviceActionType.showOrb:
        await showFloatingOrb();
        spoken = 'Floating orb দেখানো হলো।';
        _chat.addModelMessage(spoken);
        break;
      case DeviceActionType.hideOrb:
        await hideFloatingOrb();
        spoken = 'Floating orb লুকানো হলো।';
        _chat.addModelMessage(spoken);
        break;
      case DeviceActionType.sleep:
        await sleep();
        return; // sleep announces itself
      case DeviceActionType.wake:
        await wake();
        return;
    }

    if (speakIt) {
      await _configureTts();
      _setStatus(AssistantStatus.speaking, 'Speaking…');
      await tts.speak(spoken);
      if (_alive) _setStatus(AssistantStatus.idle, 'Ready');
    } else {
      _setStatus(AssistantStatus.idle, 'Ready');
    }
  }

  // ------------------------------------------------------------------
  // Floating overlay orb
  // ------------------------------------------------------------------
  Future<bool> ensureOverlayPermission() async {
    final bridge = ref.read(androidBridgeProvider);
    if (await bridge.hasOverlayPermission()) return true;
    await bridge.requestOverlayPermission();
    return false; // user must come back after granting in system settings
  }

  Future<void> showFloatingOrb() async {
    final bridge = ref.read(androidBridgeProvider);
    if (!await ensureOverlayPermission()) {
      _setStatus(AssistantStatus.error,
          'আগে "Display over other apps" অনুমতি দিন, তারপর আবার চাপুন।');
      return;
    }
    final ok = await bridge.showOverlay(mode: 'small', status: '');
    state = state.copyWith(overlayVisible: ok);
    await _settings.update((s) => s.copyWith(overlayEnabled: ok));
  }

  /// Hides the floating orb. When [notify] is true (user asked to hide it),
  /// a notification is shown so the user can still get back to MXFF AI from
  /// other apps, with an "Orb দেখাও" button.
  Future<void> hideFloatingOrb({bool notify = true}) async {
    final bridge = ref.read(androidBridgeProvider);
    await bridge.hideOverlay();
    state = state.copyWith(overlayVisible: false);
    await _settings.update((s) => s.copyWith(overlayEnabled: false));
    if (notify) {
      try {
        await ref.read(permissionServiceProvider).requestNotifications();
        await bridge.showReturnNotification();
      } catch (e) {
        debugPrint('MXFF return notification failed: $e');
      }
    }
  }

  void _syncOverlayStatus() {
    if (!state.overlayVisible) return;
    final label = switch (state.status) {
      AssistantStatus.speaking => 'MXFF AI is speaking…',
      AssistantStatus.listening => 'MXFF AI is listening…',
      AssistantStatus.thinking => 'MXFF AI is thinking…',
      _ => '',
    };
    if (label.isEmpty) return;
    ref.read(androidBridgeProvider).showOverlay(mode: 'large', status: label);
  }

  /// Called when the assistant starts speaking/listening while the app is
  /// minimised: switches the small orb to the large active overlay.
  Future<void> promoteOverlayIfNeeded() async {
    if (!state.overlayVisible) return;
    final label = switch (state.status) {
      AssistantStatus.speaking => 'MXFF AI is speaking…',
      AssistantStatus.listening => 'MXFF AI is listening…',
      AssistantStatus.thinking => 'MXFF AI is thinking…',
      _ => '',
    };
    if (label.isEmpty) return;
    await ref
        .read(androidBridgeProvider)
        .showOverlay(mode: 'large', status: label);
  }

  Future<void> demoteOverlay() async {
    if (!state.overlayVisible) return;
    await ref.read(androidBridgeProvider).showOverlay(mode: 'small', status: '');
  }

  // ------------------------------------------------------------------
  // Sleep / wake
  // ------------------------------------------------------------------
  Future<void> sleep() async {
    await stopListening();
    await stopSpeaking();
    await hideFloatingOrb(notify: false);
    state = state.copyWith(
      listeningMode: false,
      status: AssistantStatus.sleeping,
      statusText: kSleepMessage,
      overlayVisible: false,
    );
    final tts = ref.read(ttsServiceProvider);
    await tts.configure(
      locale: ref.read(settingsProvider).speechLocale,
      rate: ref.read(settingsProvider).speechRate,
      volume: ref.read(settingsProvider).ttsVolume,
      pitch: ref.read(settingsProvider).ttsPitch,
    );
    await tts.speak('MXFF AI sleeping. START চাপলে আবার জেগে উঠবো।');
    if (_alive) {
      _setStatus(AssistantStatus.sleeping, kSleepMessage, force: true);
    }
  }

  Future<void> wake() async {
    _setStatus(AssistantStatus.idle, 'Ready', force: true);
    final tts = ref.read(ttsServiceProvider);
    await _configureTts();
    await tts.speak('MXFF AI activated. বলুন, কীভাবে সাহায্য করতে পারি?');
    if (_alive) _setStatus(AssistantStatus.idle, 'Ready', force: true);
  }

  void _setStatus(AssistantStatus s, String text, {bool force = false}) {
    if (!force && state.status == AssistantStatus.sleeping && s != AssistantStatus.sleeping) {
      return; // sleeping is sticky until START
    }
    state = state.copyWith(status: s, statusText: text);
  }
}

final assistantProvider =
    NotifierProvider<AssistantNotifier, AssistantState>(AssistantNotifier.new);
