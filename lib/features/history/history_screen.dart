import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/conversation.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/providers.dart';
import '../chat/chat_tab.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final conversations = chat.conversations;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        title: const Text('Chat history'),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_rounded, color: kNeonRed),
            onPressed: conversations.isEmpty
                ? null
                : () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear all history?'),
                        content: const Text('সব conversation মুছে যাবে।'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(chatProvider.notifier).clearAll();
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: kNeonRed)),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: conversations.isEmpty
            ? const Center(
                child: Text('কোনো conversation নেই।\nHome বা Chat ট্যাব থেকে শুরু করুন।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextDim)),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ConversationCard(conversation: conversations[i]),
              ),
      ),
    );
  }
}

class _ConversationCard extends ConsumerWidget {
  const _ConversationCard({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = conversation.messages.isEmpty
        ? ''
        : conversation.messages.last.text;
    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kNeonRed.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: kNeonRed),
      ),
      onDismissed: (_) =>
          ref.read(chatProvider.notifier).deleteConversation(conversation.id),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ref.read(chatProvider.notifier).setActive(conversation.id);
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ChatPage()));
        },
        child: GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const MxffLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      last.isEmpty
                          ? '(empty)'
                          : (last.length > 60
                              ? '${last.substring(0, 60)}…'
                              : last),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: kTextDim),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${conversation.messages.length} messages • '
                      '${conversation.updatedAt.day}/${conversation.updatedAt.month}',
                      style: const TextStyle(
                          fontSize: 10, color: kTextDim),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: () => _rename(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      ref
          .read(chatProvider.notifier)
          .renameConversation(conversation.id, controller.text.trim());
    }
  }
}
