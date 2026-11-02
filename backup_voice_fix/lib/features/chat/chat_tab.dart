import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/chat_message.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/assistant_provider.dart';
import '../../state/providers.dart';

/// Full chat surface. Used embedded as the Chat tab and pushed standalone
/// from history.
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key, this.embedded = true});
  final bool embedded;

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(assistantProvider.notifier).send(text);
    _jumpBottom();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final assistant = ref.watch(assistantProvider);
    final messages = chat.active?.messages ?? const <ChatMessage>[];

    final list = Column(
      children: [
        if (!widget.embedded) _header(context, chat.active?.title ?? 'Chat'),
        Expanded(
          child: messages.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    _jumpBottom();
                    return _bubble(messages[i]);
                  },
                ),
        ),
        if (messages
            .any((m) => m.failed)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextButton.icon(
              onPressed: assistant.busy
                  ? null
                  : () => ref
                      .read(assistantProvider.notifier)
                      .retryLastFailed(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry last request'),
            ),
          ),
        ],
        _composer(assistant),
        if (!widget.embedded) const SizedBox(height: 12),
      ],
    );

    if (!widget.embedded) {
      return Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kBackground,
          title: Text(chat.active?.title ?? 'Chat'),
          actions: [
            IconButton(
              tooltip: 'Stop speaking',
              icon: const Icon(Icons.volume_off_rounded),
              onPressed: () =>
                  ref.read(assistantProvider.notifier).stopSpeaking(),
            ),
          ],
        ),
        body: SafeArea(child: list),
      );
    }
    return SafeArea(child: list);
  }

  Widget _header(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MxffLogo(size: 56),
          const SizedBox(height: 14),
          const Text('MXFF AI এর সাথে কথা বলুন',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'টাইপ করুন বা মাইক চাপুন। "Open TikTok", "Open YouTube",\n"Show floating orb", "Sleep MXFF AI" — এসব কমান্ড সরাসরি কাজ করে।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.isUser;
    final color = m.failed
        ? kNeonRed
        : (isUser ? kNeonGreen.withOpacity(0.14) : kPanelStrong);
    final border = m.failed
        ? kNeonRed
        : (isUser ? kNeonGreen.withOpacity(0.5) : const Color(0x3300D9FF));
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: border),
        ),
        child: SelectableText(
          m.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: m.failed ? kNeonRed : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _composer(AssistantState assistant) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x332EE8B0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Ask MXFF AI anything…',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          NeonIconButton(
            icon: assistant.status == AssistantStatus.listening
                ? Icons.stop_rounded
                : Icons.mic_rounded,
            color: assistant.status == AssistantStatus.listening
                ? kNeonRed
                : kNeonGreen,
            size: 42,
            onPressed: () => ref.read(assistantProvider.notifier).toggleMic(),
          ),
          const SizedBox(width: 4),
          NeonIconButton(
            icon: Icons.send_rounded,
            color: kNeonRed,
            size: 42,
            onPressed: assistant.busy ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Standalone full-screen chat page (opened from history).
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});
  @override
  Widget build(BuildContext context) => const ChatTab(embedded: false);
}
