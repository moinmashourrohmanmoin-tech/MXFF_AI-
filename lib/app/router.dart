import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../features/actions/actions_tab.dart';
import '../features/chat/chat_tab.dart';
import '../features/home/home_tab.dart';
import '../features/settings/settings_tab.dart';
import '../features/triggers/triggers_tab.dart';
import '../shared/widgets/neon_widgets.dart';
import '../state/assistant_provider.dart';

/// Route builder for pushed pages.
Route<dynamic> buildRoute(RouteSettings settings) {
  return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Wake up from sleep when the user opens the app.
    Future.microtask(() {
      final a = ref.read(assistantProvider);
      if (a.status == AssistantStatus.sleeping) {
        ref.read(assistantProvider.notifier).wake();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantProvider);

    final tabs = [
      const HomeTab(),
      const ChatTab(),
      const ActionsTab(),
      const TriggersTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      backgroundColor: kBackground,
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: MxffNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          (Icons.home_rounded, 'Home'),
          (Icons.chat_rounded, 'Chat'),
          (Icons.bolt_rounded, 'Actions'),
          (Icons.flash_on_rounded, 'Triggers'),
          (Icons.settings_rounded, 'Settings'),
        ],
      ),
      // Floating START button when sleeping.
      floatingActionButton: assistant.status == AssistantStatus.sleeping
          ? FloatingActionButton.extended(
              backgroundColor: kNeonRed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('START',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () =>
                  ref.read(assistantProvider.notifier).wake(),
            )
          : null,
    );
  }
}
