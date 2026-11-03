import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/exceptions.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/assistant_provider.dart';
import '../../state/providers.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final _keyController = TextEditingController();
  bool _keyVisible = false;
  bool? _overlayGranted;
  List<String> _modelOptions = [kAutoModel, ...kGeminiModels];
  bool _loadingModels = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    Future(() async {
      final s = ref.read(settingsProvider);
      if (mounted) {
        setState(() => _keyController.text = s.geminiApiKey);
      }
      if (s.geminiApiKey.trim().isNotEmpty) {
        _loadModels(); // detect models available for this key
      }
      _overlayGranted = await ref.read(androidBridgeProvider).hasOverlayPermission();
      if (mounted) setState(() {});
    });
  }

  Timer? _keyDebounce;

  void _scheduleModelLoad() {
    _keyDebounce?.cancel();
    _keyDebounce = Timer(const Duration(milliseconds: 900), _loadModels);
  }

  Future<void> _loadModels() async {
    final key = ref.read(settingsProvider).geminiApiKey.trim();
    if (key.isEmpty) {
      if (mounted) setState(() => _modelError = null);
      return;
    }
    if (mounted) setState(() => _loadingModels = true);
    try {
      final models = await ref.read(geminiServiceProvider).listModels(apiKey: key);
      if (!mounted) return;
      setState(() {
        _modelOptions = {kAutoModel, ...models, ...kGeminiModels}.toList();
        _modelError = null;
      });
    } on MxffException catch (e) {
      if (mounted) setState(() => _modelError = e.message);
    } catch (_) {
      if (mounted) setState(() => _modelError = 'মডেল তালিকা আনা গেল না।');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeader('Gemini AI'),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API key',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  obscureText: !_keyVisible,
                  decoration: InputDecoration(
                    hintText: 'Google AI Studio থেকে key নিন',
                    suffixIcon: IconButton(
                      icon: Icon(_keyVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _keyVisible = !_keyVisible),
                    ),
                  ),
                  onChanged: (v) {
                    settingsNotifier
                        .update((s) => s.copyWith(geminiApiKey: v.trim()));
                    _scheduleModelLoad();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Model',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (_loadingModels)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: 'মডেল তালিকা রিফ্রেশ করুন',
                        icon: const Icon(Icons.refresh_rounded,
                            size: 20, color: kNeonGreen),
                        onPressed: _loadModels,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue:
                      _modelOptions.contains(settings.model)
                          ? settings.model
                          : kDefaultGeminiModel,
                  items: _modelOptions
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m == kAutoModel
                              ? 'Auto — নিজে বেছে নেবে'
                              : m)))
                      .toList(),
                  onChanged: (v) =>
                      settingsNotifier.update((s) => s.copyWith(model: v!)),
                ),
                if (_modelError != null) ...[
                  const SizedBox(height: 6),
                  Text('মডেল তালিকা: $_modelError',
                      style: const TextStyle(
                          fontSize: 11, color: kNeonRed)),
                ],
                const SizedBox(height: 12),
                const Text('System instruction',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(
                      text: settings.systemInstruction),
                  maxLines: 3,
                  onChanged: (v) => settingsNotifier
                      .update((s) => s.copyWith(systemInstruction: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Voice'),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Language',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'auto', label: Text('Auto')),
                        ButtonSegment(value: 'bn', label: Text('বাংলা')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {settings.language},
                      onSelectionChanged: (v) => settingsNotifier
                          .update((s) => s.copyWith(language: v.first)),
                    ),
                  ],
                ),
                _slider('Speech rate', settings.speechRate, 0.1, 1.0,
                    (v) => settingsNotifier.update((s) => s.copyWith(speechRate: v))),
                _slider('Volume', settings.ttsVolume, 0.0, 1.0,
                    (v) => settingsNotifier.update((s) => s.copyWith(ttsVolume: v))),
                _slider('Pitch', settings.ttsPitch, 0.5, 2.0,
                    (v) => settingsNotifier.update((s) => s.copyWith(ttsPitch: v))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Orb & overlay'),
          GlassPanel(
            child: Column(
              children: [
                _switchTile('Orb animation', settings.orbAnimationEnabled,
                    (v) => settingsNotifier
                        .update((s) => s.copyWith(orbAnimationEnabled: v))),
                _switchTile('Floating orb (overlay)',
                    settings.overlayEnabled, (v) async {
                  final n = ref.read(assistantProvider.notifier);
                  if (v) {
                    await n.showFloatingOrb();
                  } else {
                    await n.hideFloatingOrb();
                  }
                }),
                Row(
                  children: [
                    Icon(
                      _overlayGranted == true
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 18,
                      color:
                          _overlayGranted == true ? kNeonGreen : kNeonRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _overlayGranted == true
                            ? '"Display over other apps" allowed'
                            : '"Display over other apps" permission needed',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final bridge =
                            ref.read(androidBridgeProvider);
                        await bridge.requestOverlayPermission();
                        final ok = await bridge.hasOverlayPermission();
                        if (mounted) setState(() => _overlayGranted = ok);
                      },
                      child: const Text('Allow'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Permissions'),
          GlassPanel(
            child: Column(
              children: [
                _tile('Accessibility App Control', Icons.accessibility_new_rounded, () async {
                  await ref.read(androidBridgeProvider).openAccessibilitySettings();
                }),
                _tile('Refresh permission status', Icons.refresh_rounded, () async {
                  final ok = await ref.read(androidBridgeProvider).hasAccessibilityEnabled();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok
                        ? 'MXFF AI Accessibility চালু আছে'
                        : 'Android Settings থেকে MXFF AI চালু করুন')),
                    );
                  }
                }),
                _tile('Microphone permission', Icons.mic_rounded, () async {
                  final p = ref.read(permissionServiceProvider);
                  if (await p.requestMicrophone() == null) {
                    await p.openAppSettings();
                  }
                }),
                _tile('Notification permission', Icons.notifications_rounded,
                    () async {
                  final p = ref.read(permissionServiceProvider);
                  if (await p.requestNotifications() == null) {
                    await p.openAppSettings();
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Data & privacy'),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MXFF AI আপনার কথাবার্তা ও settings শুধুমাত্র এই ফোনে সংরক্ষণ করে। '
                  'Gemini API key এবং chat history কোথাও আপলোড হয় না (AI উত্তর পেতে শুধু আপনার লেখা Google-এর Gemini সার্ভারে যায়)।',
                  style: TextStyle(fontSize: 12, color: kTextDim),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded,
                      color: kNeonRed),
                  label: const Text('Clear all chat history',
                      style: TextStyle(color: kNeonRed)),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all history?'),
                      content: const Text(
                          'সব conversation মুছে যাবে। এটি ফেরানো যাবে না।'),
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
          ),
          const SizedBox(height: 16),
          const SectionHeader('About'),
          const GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MXFF AI v2.1.0',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(
                  'Futuristic personal AI assistant — animated orb, voice conversation, '
                  'floating overlay, phone actions এবং local chat history. '
                  'AI brain: Google Gemini (auto model detection).',
                  style: TextStyle(fontSize: 12, color: kTextDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _switchTile(
          String title, bool value, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        Switch(value: value, onChanged: onChanged),
      ]);

  Widget _tile(String title, IconData icon, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: kNeonGreen),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 11, color: kTextDim)),
        ],
      );
}
