import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'web_research.dart';

/// A reply produced entirely on the phone (no AI service needed).
class LocalReply {
  const LocalReply(this.text, {this.timerSeconds});
  final String text;
  final int? timerSeconds;
}

/// MXFF AI's own rule-based skills: time, date, calculator, name memory,
/// notes and timers. Returns null when it does not know how to handle a message.
class LocalBrain {
  static const _nameKey = 'mxff_local_name';
  static const _notesKey = 'mxff_local_notes';
  static const _taughtKey = 'mxff_taught';

  static const _weekdays = [
    'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
  ];

  Future<LocalReply?> answer(String raw) async {
    final t = _normalize(raw);
    if (t.isEmpty) return null;

    // Greetings and identity
    if (t.length <= 15 &&
        RegExp(r'^(হাই|হ্যালো|hi|hello|hey|আসসালামু)').hasMatch(t)) {
      return const LocalReply(
          'হ্যালো! আমি MXFF AI। কী করতে পারি বলুন।');
    }
    if (t.contains('তুমি কে') || t.contains('who are you')) {
      return const LocalReply('আমি MXFF AI, আপনার ফোনের সহকারী।');
    }
    if (t.contains('তুমি কী পারো') ||
        t.contains('তুমি কি পারো') ||
        t.contains('what can you do')) {
      return const LocalReply(
          'আমি সময় ও তারিখ বলতে পারি, হিসাব করতে পারি, আপনার নাম মনে রাখতে পারি, নোট রাখতে পারি, টাইমার দিতে পারি, আর অ্যাপ খুলতে পারি।');
    }

    // Teach MXFF AI something: "শিখো: প্রশ্ন = উত্তর"
    final teach =
        RegExp(r'^(?:শিখো|শেখাও|teach)\s*[:]?\s*(.+?)\s*=\s*(.+)$').firstMatch(t);
    if (teach != null) {
      final q = teach.group(1)!.trim();
      final a = teach.group(2)!.trim();
      final items = await _getTaught();
      items.removeWhere((e) => e['q'] == q);
      items.add({'q': q, 'a': a});
      await _saveTaught(items);
      return LocalReply('ঠিক আছে, শিখে নিলাম। "$q" জিজ্ঞেস করলে বলব: $a');
    }
    // Forget: "ভুলে যাও প্রশ্ন"
    final forget = RegExp(r'^(?:ভুলে যাও|forget)\s+(.+)$').firstMatch(t);
    if (forget != null) {
      final q = forget.group(1)!.trim();
      final items = await _getTaught();
      final before = items.length;
      items.removeWhere((e) => e['q'] == q);
      await _saveTaught(items);
      return LocalReply(items.length < before
          ? '"$q" ভুলে গেলাম।'
          : 'এমন কিছু আমার শেখা নেই।');
    }

    // Time and date
    if (t.contains('কয়টা বাজে') ||
        t.contains('কটা বাজে') ||
        t.contains('সময় কত') ||
        t.contains('what time')) {
      final now = DateTime.now();
      return LocalReply(
          'এখন সময় ${_two(now.hour)}:${_two(now.minute)}।');
    }
    if (t.contains('আজ কত তারিখ') ||
        t.contains('আজকের তারিখ') ||
        t.contains('আজ কী বার') ||
        t.contains('আজ কি বার') ||
        t.contains('today date') ||
        t.contains('what date')) {
      final now = DateTime.now();
      final day = _weekdays[now.weekday - 1];
      return LocalReply(
          'আজ $day, ${now.day}/${now.month}/${now.year}।');
    }

    // Name memory
    if (t.contains('আমার নাম কী') ||
        t.contains('আমার নাম কি') ||
        t.contains('আমার নাম কি?') ||
        t.contains('what is my name') ||
        t.contains('my name?')) {
      final name = await _getName();
      return LocalReply(name == null
          ? 'আপনার নাম এখনো বলেননি। বলুন, "আমার নাম ..."।'
          : 'আপনার নাম $name।');
    }
    final setName =
        RegExp(r'^(?:আমার নাম|my name is)\s+(.+)$').firstMatch(t);
    if (setName != null) {
      final name = setName.group(1)!.trim();
      await _setName(name);
      return LocalReply('ঠিক আছে, আপনার নাম $name মনে রাখলাম।');
    }

    // Notes
    if (t.contains('নোট পড়ো') ||
        t.contains('আমার নোট') ||
        t.contains('নোটগুলো') ||
        t.contains('read notes') ||
        t.contains('my notes')) {
      final notes = await _getNotes();
      if (notes.isEmpty) return const LocalReply('কোনো নোট নেই।');
      final lines = <String>[];
      for (var i = 0; i < notes.length; i++) {
        lines.add('${i + 1}. ${notes[i]}');
      }
      return LocalReply('আপনার নোটগুলো: ${lines.join('; ')}');
    }
    if (t.contains('নোট মুছো') || t.contains('clear notes')) {
      await _saveNotes([]);
      return const LocalReply('সব নোট মুছে দিলাম।');
    }
    final noteMatch = RegExp(
            r'^(?:নোট|note)\s*(?:লেখো|লিখো|রাখো|সেভ করো|save)?\s*[:,-]?\s*(.+)$')
        .firstMatch(t);
    if (noteMatch != null) {
      final text = noteMatch.group(1)!.trim();
      final notes = await _getNotes();
      notes.add(text);
      await _saveNotes(notes);
      return LocalReply('নোট রাখলাম: $text');
    }

    // Timer ("৫ মিনিটের টাইমার")
    if (t.contains('টাইমার') || t.contains('timer')) {
      final m = RegExp(
              r'(\d+)\s*(সেকেন্ড|সেকেন্ডের|sec|second|seconds|মিনিট|মিনিটের|min|minute|minutes)')
          .firstMatch(t);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        final unit = m.group(2)!;
        final isMinute = unit.contains('মিনিট') || unit.contains('min');
        final seconds = (isMinute ? n * 60 : n).clamp(1, 21600).toInt();
        final label = isMinute ? '$n মিনিটের' : '$n সেকেন্ডের';
        return LocalReply('ঠিক আছে, $label টাইমার চালু হলো।',
            timerSeconds: seconds);
      }
    }

    // Calculator ("১২ গুণ ৫", "12 x 5", "10 + 3")
    final calc = RegExp(
            r'(-?\d+(?:\.\d+)?)\s*(\+|-|\*|x|×|/|গুণ|যোগ|বিয়োগ|ভাগ)\s*(-?\d+(?:\.\d+)?)')
        .firstMatch(t);
    if (calc != null) {
      final a = double.parse(calc.group(1)!);
      final b = double.parse(calc.group(3)!);
      final op = calc.group(2)!;
      if ((op == '/' || op == 'ভাগ') && b == 0) {
        return const LocalReply('শূন্য দিয়ে ভাগ করা যায় না।');
      }
      double r;
      switch (op) {
        case '+':
        case 'যোগ':
          r = a + b;
          break;
        case '-':
        case 'বিয়োগ':
          r = a - b;
          break;
        case '/':
        case 'ভাগ':
          r = a / b;
          break;
        default:
          r = a * b;
      }
      final shown = r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(2);
      return LocalReply('উত্তর $shown।');
    }

    // Things MXFF AI was taught earlier
    final learned = await _bestTaught(t);
    if (learned != null) return LocalReply(learned);

    // Factual questions: look them up in Wikipedia (no AI involved).
    final web = await WebResearch.answer(t);
    if (web != null) return LocalReply(web);

    return null;
  }

  // ---------------------------------------------------------------
  Future<String?> _bestTaught(String t) async {
    final words = t.split(' ').where((w) => w.length > 1).toSet();
    if (words.isEmpty) return null;
    String? best;
    double bestScore = 0;
    for (final e in await _getTaught()) {
      final qWords =
          (e['q'] ?? '').split(' ').where((w) => w.length > 1).toSet();
      if (qWords.isEmpty) continue;
      final score = words.intersection(qWords).length / qWords.length;
      if (score >= 0.6 && score > bestScore) {
        bestScore = score;
        best = e['a'];
      }
    }
    return best;
  }

  Future<List<Map<String, String>>> _getTaught() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_taughtKey);
    if (raw == null || raw.isEmpty) return <Map<String, String>>[];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  Future<void> _saveTaught(List<Map<String, String>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taughtKey, jsonEncode(items));
  }

  String _normalize(String raw) {
    const bn = '০১২৩৪৫৬৭৮৯';
    var s = raw.toLowerCase().trim();
    for (var i = 0; i < bn.length; i++) {
      s = s.replaceAll(bn[i], '$i');
    }
    s = s.replaceAll(RegExp(r'[?।!]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<String?> _getName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_nameKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }

  Future<List<String>> _getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _saveNotes(List<String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, jsonEncode(notes));
  }
}
