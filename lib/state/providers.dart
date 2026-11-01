import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/chat_store.dart';
import '../data/local/settings_store.dart';
import '../data/models/app_settings.dart';
import '../data/models/chat_message.dart';
import '../data/models/conversation.dart';
import '../services/android/android_bridge.dart';
import '../services/gemini/gemini_service.dart';
import '../services/permissions/permission_service.dart';
import '../services/speech/speech_service.dart';
import '../services/tts/tts_service.dart';

// ---------- Simple providers ----------
final geminiServiceProvider =
    Provider<GeminiService>((ref) => GeminiService());
final androidBridgeProvider = Provider<AndroidBridge>((ref) => AndroidBridge());
final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());
final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(tts.dispose);
  return tts;
});
final speechServiceProvider = Provider<SpeechService>((ref) {
  final s = SpeechService();
  ref.onDispose(s.dispose);
  return s;
});
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());
final chatStoreProvider = Provider<ChatStore>((ref) => ChatStore());

// ---------- Settings ----------
class SettingsNotifier extends Notifier<AppSettings> {
  bool _alive = true;

  @override
  AppSettings build() {
    ref.onDispose(() => _alive = false);
    final store = ref.read(settingsStoreProvider);
    store.load().then((s) {
      if (_alive && s != state) state = s;
    });
    return const AppSettings();
  }

  Future<void> update(AppSettings Function(AppSettings) changer) async {
    state = changer(state);
    await ref.read(settingsStoreProvider).save(state);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------- Conversations ----------
class ChatState {
  final List<Conversation> conversations;
  final String activeId;
  final bool loaded;
  const ChatState({
    this.conversations = const [],
    this.activeId = '',
    this.loaded = false,
  });

  Conversation? get active =>
      conversations.where((c) => c.id == activeId).firstOrNull;

  ChatState copyWith({
    List<Conversation>? conversations,
    String? activeId,
    bool? loaded,
  }) =>
      ChatState(
        conversations: conversations ?? this.conversations,
        activeId: activeId ?? this.activeId,
        loaded: loaded ?? this.loaded,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  bool _alive = true;

  @override
  ChatState build() {
    ref.onDispose(() => _alive = false);
    _load();
    return const ChatState(loaded: false);
  }

  Future<void> _load() async {
    final list = await ref.read(chatStoreProvider).load();
    if (!_alive) return;
    state = state.copyWith(
      conversations: list,
      loaded: true,
      activeId: state.activeId.isEmpty && list.isNotEmpty ? list.first.id : null,
    );
  }

  String ensureActiveConversation([String? titleSeed]) {
    final existing = state.active;
    if (existing != null) return existing.id;
    final id = 'c${DateTime.now().millisecondsSinceEpoch}';
    final conv = Conversation(
      id: id,
      title: Conversation.autoTitle(titleSeed ?? 'New chat'),
      messages: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(
      conversations: [conv, ...state.conversations],
      activeId: id,
    );
    _persist();
    return id;
  }

  void setActive(String id) => state = state.copyWith(activeId: id);

  void addUserMessage(String text) {
    _append(ChatMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      text: text,
      time: DateTime.now(),
    ));
  }

  void addModelMessage(String text, {bool failed = false}) {
    _append(ChatMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      role: 'model',
      text: text,
      time: DateTime.now(),
      failed: failed,
    ));
  }

  void replaceLastModelMessage(String text, {bool failed = false}) {
    final active = state.active;
    if (active == null || active.messages.isEmpty) return;
    final msgs = [...active.messages];
    final last = msgs.last;
    if (last.role != 'model') return;
    msgs[msgs.length - 1] = last.copyWith(text: text, failed: failed);
    _updateConversation(active.id, active..messages = msgs);
  }

  void removeLastModelMessage() {
    final active = state.active;
    if (active == null || active.messages.isEmpty) return;
    final msgs = [...active.messages];
    if (msgs.last.role != 'model') return;
    msgs.removeLast();
    _updateConversation(active.id, active..messages = msgs);
  }

  void _append(ChatMessage m) {
    final id = state.activeId.isEmpty ? ensureActiveConversation(m.text) : state.activeId;
    final active = state.active!;
    final conv = active
      ..messages = [...active.messages, m]
      ..updatedAt = DateTime.now();
    if (m.role == 'user' && active.messages.isEmpty) {
      conv.title = Conversation.autoTitle(m.text);
    }
    _updateConversation(id, conv);
  }

  void _updateConversation(String id, Conversation conv) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == id ? Conversation(
                id: c.id,
                title: conv.title,
                messages: conv.messages,
                createdAt: c.createdAt,
                updatedAt: conv.updatedAt,
              ) : c)
          .toList(),
    );
    _persist();
  }

  void renameConversation(String id, String title) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == id ? (c..title = title) : c)
          .toList(),
    );
    _persist();
  }

  void deleteConversation(String id) {
    final remaining = state.conversations.where((c) => c.id != id).toList();
    state = state.copyWith(
      conversations: remaining,
      activeId: state.activeId == id
          ? (remaining.isNotEmpty ? remaining.first.id : '')
          : null,
    );
    _persist();
  }

  Future<void> clearAll() async {
    state = state.copyWith(conversations: [], activeId: '');
    await ref.read(chatStoreProvider).clear();
  }

  Future<void> _persist() =>
      ref.read(chatStoreProvider).save(state.conversations);
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
