import 'constants.dart';

enum DeviceActionType { openApp, minimizeApp, showOrb, hideOrb, sleep, wake }

class DeviceAction {
  final DeviceActionType type;
  final String label;
  final String? packageName;
  const DeviceAction(this.type, this.label, {this.packageName});
}

/// Rule-based offline command parser (English + Bengali).
/// Runs before Gemini so common phone commands work instantly, even offline.
///
/// NOTE: Dart's default RegExp `\b` only understands ASCII letters, so it never
/// matches Bengali words. We use Unicode letter/mark lookarounds instead, which
/// work for both English and Bengali keywords.
class CommandParser {
  CommandParser._();

  /// Builds a whole-word matcher that works for Bengali and English.
  static RegExp _words(String alternatives) => RegExp(
        '(?<![\\p{L}\\p{M}])(?:$alternatives)(?![\\p{L}\\p{M}])',
        caseSensitive: false,
        unicode: true,
      );

  static final RegExp _openWords = _words(
    r'open|launch|start|go to|খোলো|খুলো|ওপেন|চালাও|খোল',
  );
  static final RegExp _minimizeWords = _words(
    r'minimize|minimise|background|going home|মিনিমাইজ|ব্যাকগ্রাউন্ড|ব্যাক',
  );
  static final RegExp _showOrbWords = _words(
    r'show|display|enable|float|floating|orb|bubble|ফ্লোটিং|ফ্লোট|বাবল|অর্ব|দেখাও|চালু',
  );
  static final RegExp _hideOrbWords = _words(
    r'hide|remove|disable|ফ্লোটিং|বাবল|অর্ব|লুকাও|বন্ধ|সরাও',
  );
  static final RegExp _sleepWords = _words(
    r'sleep|good ?night|ঘুমা|ঘুমাও|স্লিপ|বন্ধ হও|শাও',
  );

  // Action-specific keyword sets (no boundaries needed: they are checked
  // as plain substrings of the already-lowercased text).
  static final RegExp _hideVerb = RegExp(r'(hide|লুকাও|সরাও|বন্ধ)');
  static final RegExp _orbNoun = RegExp(r'(orb|bubble|ফ্লোটিং|বাবল|অর্ব)');
  static final RegExp _showVerb = RegExp(r'(show|display|enable|দেখাও|চালু|ফ্লোটিং)');

  /// Returns null when the text is not a recognised device command.
  static DeviceAction? parse(String raw) {
    final text = raw.toLowerCase().trim();
    if (text.isEmpty) return null;

    if (_sleepWords.hasMatch(text) && !_openWords.hasMatch(text)) {
      return const DeviceAction(DeviceActionType.sleep, 'Sleep MXFF AI');
    }
    if (_minimizeWords.hasMatch(text) && !_openWords.hasMatch(text)) {
      return const DeviceAction(DeviceActionType.minimizeApp, 'Minimize MXFF AI');
    }
    if (_hideOrbWords.hasMatch(text) &&
        _hideVerb.hasMatch(text) &&
        _orbNoun.hasMatch(text)) {
      return const DeviceAction(DeviceActionType.hideOrb, 'Hide floating Orb');
    }
    if (_showOrbWords.hasMatch(text) &&
        _showVerb.hasMatch(text) &&
        _orbNoun.hasMatch(text)) {
      return const DeviceAction(DeviceActionType.showOrb, 'Show floating Orb');
    }

    if (_openWords.hasMatch(text)) {
      // Try longest alias first so "google chrome" matches before "chrome".
      final candidates = <({LaunchApp app, String alias})>[];
      for (final app in kLaunchApps) {
        for (final alias in app.aliases) {
          if (text.contains(alias.toLowerCase())) {
            candidates.add((app: app, alias: alias));
          }
        }
      }
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) => b.alias.length.compareTo(a.alias.length));
      final best = candidates.first.app;
      return DeviceAction(DeviceActionType.openApp, 'Open ${best.name}',
          packageName: best.package);
    }
    return null;
  }
}
