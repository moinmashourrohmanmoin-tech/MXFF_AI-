import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a factual question in Wikipedia (Bengali first, then English).
/// This is a plain encyclopedia search, not an AI: it returns the opening
/// paragraph of the best matching article, with the source named.
class WebResearch {
  static const _questionWords = {
    'কী', 'কি', 'কে', 'কোথায়', 'কবে', 'কেন', 'কীভাবে', 'কিভাবে', 'কত',
    'কোনটা', 'মানে', 'বলো', 'বল', 'what', 'who', 'where', 'when', 'why',
    'how', 'is', 'are', 'the', 'a',
  };

  static Future<String?> answer(String question) async {
    try {
      final tokens = question.split(' ').where((w) => w.isNotEmpty).toList();
      if (!tokens.any(_questionWords.contains)) return null;

      final topic = tokens.where((w) => !_questionWords.contains(w)).join(' ');
      if (topic.length < 3) return null;

      final preferBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(topic);
      final order = preferBengali ? ['bn', 'en'] : ['en', 'bn'];

      for (final lang in order) {
        final title = await _findTitle(lang, topic);
        if (title == null) continue;
        final extract = await _extract(lang, title);
        if (extract == null || extract.isEmpty) continue;
        // Only accept an article that actually mentions the topic words.
        // Otherwise the search picked an unrelated page.
        final words = topic
            .toLowerCase()
            .split(' ')
            .where((w) => w.length >= 3)
            .toList();
        final haystack = '${title.toLowerCase()} ${extract.toLowerCase()}';
        if (words.isEmpty || !words.any(haystack.contains)) continue;
        final text = extract.replaceAll(RegExp(r'\s+'), ' ').trim();
        final short = text.length > 350 ? '${text.substring(0, 350)}…' : text;
        return 'উইকিপিডিয়া থেকে ($title): $short';
      }
      return null;
    } catch (_) {
      return null; // no internet or the site did not answer
    }
  }

  static Future<String?> _findTitle(String lang, String q) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': q,
      'srlimit': '1',
      'format': 'json',
    });
    final r = await http
        .get(uri, headers: {'User-Agent': 'MXFF-AI/1.0'})
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (j['query']?['search'] as List?) ?? const [];
    if (list.isEmpty) return null;
    return (list.first as Map)['title'] as String?;
  }

  static Future<String?> _extract(String lang, String title) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts',
      'exintro': '1',
      'explaintext': '1',
      'redirects': '1',
      'titles': title,
      'format': 'json',
    });
    final r = await http
        .get(uri, headers: {'User-Agent': 'MXFF-AI/1.0'})
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final pages = (j['query']?['pages'] as Map?) ?? const {};
    if (pages.isEmpty) return null;
    final page = pages.values.first as Map;
    return page['extract'] as String?;
  }
}
