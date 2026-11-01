/// MXFF AI design + system constants.
library;

import 'package:flutter/material.dart';

// ---------- Colors ----------
const kBackground = Color(0xFF04060A);
const kPanel = Color(0xFF0C1118);
const kPanelStrong = Color(0xFF121A24);
const kNeonGreen = Color(0xFF00F5A0);
const kNeonRed = Color(0xFFFF2449);
const kCyan = Color(0xFF00D9FF);
const kTextDim = Color(0xFF9FB0AC);

// ---------- Package identity ----------
const kMxffPackage = 'com.mxff.ai';

// ---------- Overlay channel ----------
const kBridgeChannel = 'com.mxff.ai/bridge';

// ---------- Launchable apps (package -> display name + aliases) ----------
class LaunchApp {
  final String package;
  final String name;
  final IconData icon;
  final List<String> aliases; // english + bengali spoken forms
  const LaunchApp(this.package, this.name, this.icon, this.aliases);
}

const kLaunchApps = <LaunchApp>[
  LaunchApp('com.zhiliaoapp.musically', 'TikTok', Icons.music_note,
      ['tiktok', 'টিকটক', 'টিক টক']),
  LaunchApp('com.google.android.youtube', 'YouTube', Icons.play_circle_fill,
      ['youtube', 'ইউটিউব', 'ইউ টিউব']),
  LaunchApp('com.android.chrome', 'Chrome', Icons.public,
      ['chrome', 'ক্রোম', 'গুগল ক্রোম']),
  LaunchApp('com.facebook.katana', 'Facebook', Icons.facebook,
      ['facebook', 'ফেসবুক']),
  LaunchApp('com.instagram.android', 'Instagram', Icons.camera_alt,
      ['instagram', 'ইনস্টাগ্রাম', 'ইনস্টা']),
  LaunchApp('com.whatsapp', 'WhatsApp', Icons.chat,
      ['whatsapp', 'হোয়াটসঅ্যাপ', 'হোয়াটস অ্যাপ']),
  LaunchApp('com.google.android.gm', 'Gmail', Icons.mail,
      ['gmail', 'জিমেইল', 'মেইল']),
  LaunchApp('com.google.android.apps.maps', 'Maps', Icons.map,
      ['maps', 'ম্যাপস', 'ম্যাপ', 'গুগল ম্যাপ']),
  LaunchApp('com.whatsapp.w4b', 'WhatsApp Business', Icons.chat_bubble,
      ['whatsapp business']),
  LaunchApp('com.android.settings', 'Settings', Icons.settings,
      ['settings', 'সেটিংস', 'সেটিং', 'সেটিংস খোলো']),
  LaunchApp('com.android.camera2', 'Camera', Icons.photo_camera,
      ['camera', 'ক্যামেরা']),
  LaunchApp('com.sec.android.app.popupcalculator', 'Calculator', Icons.calculate,
      ['calculator', 'ক্যালকুলেটর']),
];

// ---------- Gemini defaults ----------
/// 'auto' = MXFF AI detects a working model from the user's API key.
const kAutoModel = 'auto';
/// Used only when model detection fails entirely (e.g. no network).
const kFallbackGeminiModel = 'gemini-2.5-flash';
const kDefaultGeminiModel = kAutoModel;
const kGeminiModels = [
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.5-pro',
  'gemini-2.0-flash',
];

const kDefaultSystemInstruction =
    'You are MXFF AI, a helpful, honest and friendly personal assistant living on the '
    'user\'s Android phone. Reply in the same language the user writes in '
    '(Bengali or English). Keep spoken-style answers reasonably short and clear '
    'because your answers may be read aloud. Never claim to control devices '
    'beyond what MXFF AI actually supports.';

const kSleepMessage = 'MXFF AI slept. Open the app and press START to wake me.';
