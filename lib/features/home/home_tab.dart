import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/command_parser.dart';
import '../../features/history/history_screen.dart';
import '../../core/constants.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/assistant_provider.dart';
import '../../state/providers.dart';
import '../orb/mxff_orb.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  OrbState _orbState(AssistantStatus s) {
    switch (s) {
      case AssistantStatus.listening:
        return OrbState.listening;
      case AssistantStatus.thinking:
        return OrbState.thinking;
      case AssistantStatus.speaking:
        return OrbState.speaking;
      default:
        return OrbState.idle;
    }
  }

  String _greeting(AssistantStatus s) {
    switch (s) {
      case AssistantStatus.listening:
        return "Hello, user. I'm listening…";
      case AssistantStatus.thinking:
        return 'Thinking…';
      case AssistantStatus.speaking:
        return 'Speaking…';
      case AssistantStatus.sleeping:
        return 'Sleeping — press START to wake me.';
      case AssistantStatus.error:
        return 'Something went wrong. Try again.';
      default:
        return "Hello, user. I'm ready to help.";
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _focus.unfocus();
    await ref.read(assistantProvider.notifier).send(text);
  }

  Future<void> _mic() => ref.read(assistantProvider.notifier).toggleMic();

  Future<void> _toggleOrb() async {
    final a = ref.read(assistantProvider);
    if (a.overlayVisible) {
      await ref.read(assistantProvider.notifier).hideFloatingOrb();
    } else {
      await ref.read(assistantProvider.notifier).showFloatingOrb();
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantProvider);
    final settings = ref.watch(settingsProvider);
    final hasKey = settings.geminiApiKey.trim().isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Header ----
            Row(
              children: [
                const MxffLogo(),
                const SizedBox(width: 10),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    children: [
                      TextSpan(text: 'MXFF '),
                      TextSpan(text: 'AI', style: TextStyle(color: kNeonGreen)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Chat history',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  icon: const Icon(Icons.history_rounded, color: kTextDim),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---- Greeting ----
            Text('MXFF AI, your assistant',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(_greeting(assistant.status),
                style: const TextStyle(color: kTextDim, fontSize: 14)),

            // ---- Orb ----
            const SizedBox(height: 8),
            Center(
              child: settings.orbAnimationEnabled
                  ? MxffOrb(
                      size: MediaQuery.of(context).size.width * 0.72,
                      state: _orbState(assistant.status))
                  : const Icon(Icons.blur_circular_rounded,
                      size: 200, color: kNeonRed),
            ),
            const SizedBox(height: 8),

            // ---- Status ----
            Center(
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      StatusDot(
                        color: assistant.status == AssistantStatus.error
                            ? kNeonRed
                            : (hasKey ? kNeonGreen : kNeonRed),
                        label: assistant.status == AssistantStatus.error
                            ? 'ERROR'
                            : (hasKey ? 'AI ONLINE' : 'AI OFFLINE (no API key)'),
                      ),
                      const SizedBox(width: 16),
                      StatusDot(
                        color: assistant.listeningMode ? kNeonGreen : kTextDim,
                        label: assistant.listeningMode
                            ? 'VOICE ON'
                            : 'VOICE STANDBY',
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(assistant.statusText,
                        style: const TextStyle(fontSize: 12, color: kTextDim),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Composer ----
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
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
                    size: 44,
                    onPressed: _mic,
                    tooltip: 'Microphone',
                  ),
                  const SizedBox(width: 6),
                  NeonIconButton(
                    icon: Icons.send_rounded,
                    color: kNeonRed,
                    size: 44,
                    onPressed: assistant.busy ? null : _send,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- Quick actions ----
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                QuickAction(
                  icon: Icons.mic_rounded,
                  label: 'Voice',
                  onTap: _mic,
                ),
                QuickAction(
                  icon: assistant.overlayVisible
                      ? Icons.hide_source_rounded
                      : Icons.picture_in_picture_rounded,
                  label: assistant.overlayVisible
                      ? 'Hide Floating Orb'
                      : 'Floating Orb',
                  color: kCyan,
                  onTap: _toggleOrb,
                ),
                QuickAction(
                  icon: assistant.status == AssistantStatus.sleeping
                      ? Icons.power_settings_new
                      : Icons.bedtime_rounded,
                  label: assistant.status == AssistantStatus.sleeping
                      ? 'START'
                      : 'Sleep',
                  color: kNeonRed,
                  onTap: () {
                    if (assistant.status == AssistantStatus.sleeping) {
                      ref.read(assistantProvider.notifier).wake();
                    } else {
                      ref.read(assistantProvider.notifier).runAction(
                          const DeviceAction(
                              DeviceActionType.sleep, 'Sleep MXFF AI'));
                    }
                  },
                ),
                QuickAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Minimize',
                  color: kCyan,
                  onTap: () =>
                      ref.read(androidBridgeProvider).minimizeApp(),
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
