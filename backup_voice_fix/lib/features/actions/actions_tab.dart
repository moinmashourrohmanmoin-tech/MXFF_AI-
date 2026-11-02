import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/command_parser.dart';
import '../../core/constants.dart';
import '../../shared/widgets/neon_widgets.dart';
import '../../state/assistant_provider.dart';
import '../../state/providers.dart';

class ActionsTab extends ConsumerStatefulWidget {
  const ActionsTab({super.key});

  @override
  ConsumerState<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends ConsumerState<ActionsTab> {
  final Map<String, bool> _installed = {};

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    final bridge = ref.read(androidBridgeProvider);
    for (final app in kLaunchApps) {
      final ok = await bridge.isAppInstalled(app.package);
      if (mounted) setState(() => _installed[app.package] = ok);
    }
  }

  Future<void> _open(String pkg, String name) async {
    final notifier = ref.read(assistantProvider.notifier);
    await notifier.runAction(DeviceAction(
        DeviceActionType.openApp, 'Open $name',
        packageName: pkg), speakIt: true);
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantProvider);
    final bridge = ref.read(androidBridgeProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeader('Phone actions'),
          const Text(
              'MXFF AI দিয়ে ইনস্টল করা অ্যাপ সরাসরি খুলুন — Play Store এ যাবে না।',
              style: TextStyle(fontSize: 12, color: kTextDim)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kLaunchApps.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (_, i) {
              final app = kLaunchApps[i];
              final installed = _installed[app.package] ?? true;
              return Opacity(
                opacity: installed ? 1 : 0.35,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: installed ? () => _open(app.package, app.name) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kPanelStrong,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: kNeonGreen.withOpacity(0.35)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(app.icon, color: kNeonGreen, size: 30),
                        const SizedBox(height: 6),
                        Text(app.name,
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const SectionHeader('Floating Orb'),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assistant.overlayVisible
                            ? 'Floating Orb is ON'
                            : 'Floating Orb is OFF',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    Switch(
                      value: assistant.overlayVisible,
                      onChanged: (_) async {
                        final notifier = ref.read(assistantProvider.notifier);
                        if (assistant.overlayVisible) {
                          await notifier.hideFloatingOrb();
                        } else {
                          await notifier.showFloatingOrb();
                        }
                      },
                    ),
                  ],
                ),
                const Text(
                  'ছোট orb ড্র্যাগ করা যায়; ট্যাপ করলে MXFF AI খুলবে, লম্বা চাপলে লুকাবে।',
                  style: TextStyle(fontSize: 12, color: kTextDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Assistant'),
          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.minimize_rounded,
                  label: 'Minimize MXFF AI',
                  color: kCyan,
                  onTap: () => bridge.minimizeApp(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: assistant.status == AssistantStatus.sleeping
                      ? Icons.power_settings_new
                      : Icons.bedtime_rounded,
                  label: assistant.status == AssistantStatus.sleeping
                      ? 'START'
                      : 'Sleep MXFF AI',
                  color: kNeonRed,
                  onTap: () {
                    final n = ref.read(assistantProvider.notifier);
                    if (assistant.status == AssistantStatus.sleeping) {
                      n.wake();
                    } else {
                      n.runAction(const DeviceAction(
                          DeviceActionType.sleep, 'Sleep MXFF AI'));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
