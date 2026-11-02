import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'router.dart';

/// MXFF AI app shell: bottom navigation with 5 tabs
/// (Home, Chat, Actions, Triggers, Settings).
class MxffApp extends StatelessWidget {
  const MxffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MXFF AI',
      debugShowCheckedModeBanner: false,
      theme: MxffTheme.dark(),
      home: const MainShell(),
    );
  }
}
