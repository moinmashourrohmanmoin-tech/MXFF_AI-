import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/assistant_provider.dart';
import '../../state/providers.dart';

class TriggersTab extends ConsumerStatefulWidget {
  const TriggersTab({super.key});

  @override
  ConsumerState<TriggersTab> createState() => _TriggersTabState();
}

class _TriggersTabState extends ConsumerState<TriggersTab> {
  bool? _micGranted;

  @override
  void initState() {
    super.initState();
    ref.read(permissionServiceProvider).hasMicrophone().then((v) {
      if (mounted) setState(() => _micGranted = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final assistant = ref.watch(assistantProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeader('Wake word & listening'),
          const Text(
            'সতর্কতা: Android সাধারণ অ্যাপকে ব্যাকগ্রাউন্ডে সবসময় মাইক্রোফোন চালু রাখতে দেয় না। '
            'তাই MXFF AI-এর লিসেনিং মোড কাজ করে যখন অ্যাপটি খোলা বা সামনে থাকে। '
            'অন্য অ্যাপ ব্যবহারের সময় ভয়েস দরকার হলে floating orb-এ ট্যাপ করে MXFF AI খুলে নিন।',
            style: TextStyle(fontSize: 12, color: kTextDim),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Listening mode (app open)',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: assistant.listeningMode,
                      onChanged: (_) => ref
                          .read(assistantProvider.notifier)
                          .toggleListeningMode(),
                    ),
                  ],
                ),
                Text(
                  assistant.listeningMode
                      ? 'চালু আছে — "${settings.wakePhrase}" বললে MXFF AI জেগে উঠবো।'
                      : 'চালু করলে অ্যাপ খোলা অবস্থায় MXFF AI সবসময় শুনবে।',
                  style: const TextStyle(fontSize: 12, color: kTextDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wake phrase',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: settings.wakePhrase),
                  decoration: const InputDecoration(
                      hintText: 'যেমন: MXFF'),
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(wakePhrase: v)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'উচ্চারণ-বান্ধব বাংলা শব্দও দেওয়া যায় (যেমন: মক্সফ)।',
                  style: TextStyle(fontSize: 11, color: kTextDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Microphone status'),
          GlassPanel(
            child: Row(
              children: [
                Icon(
                  _micGranted == true
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: _micGranted == true ? kNeonGreen : kNeonRed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _micGranted == null
                        ? 'Checking…'
                        : (_micGranted!
                            ? 'Microphone permission granted'
                            : 'Microphone permission missing'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final p = ref.read(permissionServiceProvider);
                    final r = await p.requestMicrophone();
                    if (r == null) {
                      await p.openAppSettings();
                    }
                    final v = await p.hasMicrophone();
                    if (mounted) setState(() => _micGranted = v);
                  },
                  child: const Text('Allow'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
