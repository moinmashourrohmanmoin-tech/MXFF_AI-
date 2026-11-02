import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/exceptions.dart';

/// Gemini REST service (generativelanguage.googleapis.com).
/// Multi-turn, system-instruction aware, friendly error mapping.
///
/// Model handling:
/// - `auto` (or an unknown/retired model id) is resolved against the
///   ListModels endpoint so the assistant always uses a model that the
///   user's key can actually call.
/// - If the configured model is unavailable (404), the request is retried
///   once with a working model detected from the key.
class GeminiAnswer {
  final String text;
  final String modelUsed;
  const GeminiAnswer(this.text, this.modelUsed);
}

class GeminiService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// history entries: {'role': 'user'|'model', 'text': ...}
  Future<GeminiAnswer> ask({
    required String apiKey,
    required String model,
    required String systemInstruction,
    required List<Map<String, String>> history,
    required String prompt,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const MxffException(
          'Gemini API key নেই। Settings ট্যাবে গিয়ে আপনার key বসান।');
    }

    var modelId = model.trim();
    if (modelId.isEmpty || modelId == kAutoModel) {
      modelId = await resolveModel(apiKey: key) ?? kFallbackGeminiModel;
    }

    try {
      final text = await _callModel(
        key: key,
        model: modelId,
        systemInstruction: systemInstruction,
        history: history,
        prompt: prompt,
      );
      return GeminiAnswer(text, modelId);
    } on MxffException catch (e) {
      if (!e.modelUnavailable) rethrow;
      // The configured model is not available for this key — detect a
      // working one and retry once, so MXFF AI keeps talking.
      final fallback = await resolveModel(apiKey: key, preferred: modelId);
      if (fallback == null || fallback == modelId) rethrow;
      final text = await _callModel(
        key: key,
        model: fallback,
        systemInstruction: systemInstruction,
        history: history,
        prompt: prompt,
      );
      return GeminiAnswer(text, fallback);
    }
  }

  Future<String> _callModel({
    required String key,
    required String model,
    required String systemInstruction,
    required List<Map<String, String>> history,
    required String prompt,
  }) async {
    final contents = [
      ...history.map((m) => {
            'role': m['role'] == 'model' ? 'model' : 'user',
            'parts': [
              {'text': m['text']}
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    final uri =
        Uri.parse('$_baseUrl/models/$model:generateContent').replace(
      queryParameters: {'key': key},
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {'maxOutputTokens': 2048},
    });

    late http.Response r;
    try {
      r = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const MxffException(
          'ইন্টারনেট সংযোগ পাওয়া যায়নি। নেটওয়ার্ক চেক করে আবার চেষ্টা করুন।',
          retryable: true);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw MxffException('Gemini থেকে অদ্ভুত উত্তর এসেছে (HTTP ${r.statusCode}).',
          retryable: r.statusCode >= 500);
    }

    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = (data['error']?['message'] as String?) ?? 'Gemini error';
      throw MxffException(_friendlyError(r.statusCode, msg, model),
          retryable: r.statusCode == 429 || r.statusCode >= 500,
          modelUnavailable: _isModelUnavailable(r.statusCode, msg));
    }

    final candidates = data['candidates'] as List? ?? [];
    if (candidates.isEmpty) {
      final blocked = data['promptFeedback']?['blockReason'];
      if (blocked != null) {
        throw MxffException('উত্তরটি Gemini এর নিরাপত্তা নীতিতে আটকে গেছে ($blocked).');
      }
      throw const MxffException('Gemini খালি উত্তর দিয়েছে। আবার চেষ্টা করুন।',
          retryable: true);
    }

    final parts =
        ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? [];
    final answer = parts
        .map((e) => (e as Map)['text'] as String? ?? '')
        .join()
        .trim();
    if (answer.isEmpty) {
      throw const MxffException('Gemini খালি উত্তর দিয়েছে। আবার চেষ্টা করুন।',
          retryable: true);
    }
    return answer;
  }

  /// Lists model ids that this key can call for generateContent.
  Future<List<String>> listModels({required String apiKey}) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const MxffException(
          'Gemini API key নেই। Settings ট্যাবে গিয়ে আপনার key বসান।');
    }
    final uri = Uri.parse('$_baseUrl/models').replace(
      queryParameters: {'key': key, 'pageSize': '200'},
    );

    late http.Response r;
    try {
      r = await http.get(uri).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const MxffException(
          'ইন্টারনেট সংযোগ পাওয়া যায়নি। নেটওয়ার্ক চেক করে আবার চেষ্টা করুন।',
          retryable: true);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw MxffException(
          'মডেল তালিকা পড়া গেল না (HTTP ${r.statusCode}).', retryable: true);
    }

    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = (data['error']?['message'] as String?) ?? 'Gemini error';
      throw MxffException(_friendlyError(r.statusCode, msg, ''),
          modelUnavailable: _isModelUnavailable(r.statusCode, msg));
    }

    final models = data['models'] as List? ?? [];
    final ids = <String>[];
    for (final m in models) {
      final name = (m as Map)['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final id = name.startsWith('models/') ? name.substring(7) : name;
      final methods =
          (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? const [];
      if (methods.isNotEmpty && !methods.contains('generateContent')) continue;
      if (_excludedModel(id)) continue;
      ids.add(id);
    }
    ids.sort();
    return ids;
  }

  bool _excludedModel(String id) {
    const banned = [
      'embedding', 'embed', 'imagen', 'image-generation', 'image-generation',
      'aqa', 'tts', 'veo', 'live', 'native-audio', 'vision', 'robotics',
      'computer-use', 'aistudio'
    ];
    final lower = id.toLowerCase();
    return banned.any(lower.contains);
  }

  /// Picks the best available model for this key.
  /// Preference: the currently configured model (if it still works),
  /// then a Gemini flash model, then any Gemini model, then anything.
  Future<String?> resolveModel({
    required String apiKey,
    String preferred = '',
  }) async {
    try {
      final models = await listModels(apiKey: apiKey);
      return pickBestGeminiModel(models, preferred);
    } on MxffException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  bool _isModelUnavailable(int status, String msg) {
    if (status == 404) return true;
    if (status == 400) {
      final lower = msg.toLowerCase();
      return lower.contains('not found') ||
          lower.contains('not supported') ||
          lower.contains('not available') ||
          lower.contains('does not exist');
    }
    return false;
  }

  String _friendlyError(int status, String msg, [String model = '']) {
    final lower = msg.toLowerCase();
    switch (status) {
      case 400:
        if (lower.contains('api key not valid') ||
            lower.contains('api_key_invalid')) {
          return 'API key সঠিক নয়। Settings এ আবার চেক করুন।';
        }
        if (_isModelUnavailable(status, msg)) {
          return 'মডেলটি আপনার key-তে পাওয়া যায়নি। MXFF AI নিজে থেকেই চালু মডেল বেছে নেওয়ার চেষ্টা করবে।';
        }
        return 'অনুরোধটি ভুল হয়েছে: $msg';
      case 401:
      case 403:
        return 'API key ভুল বা অনুমতি নেই। Settings এ key আপডেট করুন।';
      case 404:
        return 'মডেলটি আপনার key-তে পাওয়া যায়নি। MXFF AI নিজে থেকেই চালু মডেল বেছে নেওয়ার চেষ্টা করবে।';
      case 429:
        return 'অনেক বেশি অনুরোধ হয়েছে (rate limit)। একটু পরে আবার চেষ্টা করুন।';
      case 500:
      case 503:
        return 'Gemini সার্ভারে সমস্যা হচ্ছে। একটু পরে আবার চেষ্টা করুন।';
      default:
        return 'Gemini ত্রুটি (HTTP $status): $msg';
    }
  }
}

/// Pure model picker so it can be unit-tested.
/// Order: preferred id (if present) > gemini flash (non-lite) > gemini flash
/// > gemini pro > any gemini > first entry. Returns null for an empty list.
String? pickBestGeminiModel(List<String> models, String preferred) {
  if (models.isEmpty) return null;
  final wanted = preferred.trim();
  if (wanted.isNotEmpty && wanted != kAutoModel && models.contains(wanted)) {
    return wanted;
  }
  final geminiModels = models
      .where((m) => m.startsWith('gemini') || m.startsWith('gemma'))
      .toList();
  for (final want in ['flash', 'pro']) {
    final full = geminiModels
        .where((m) => m.contains(want) && !m.contains('lite'))
        .toList();
    if (full.isNotEmpty) return full.first;
    final withLite = geminiModels.where((m) => m.contains(want)).toList();
    if (withLite.isNotEmpty) return withLite.first;
  }
  if (geminiModels.isNotEmpty) return geminiModels.first;
  return models.first;
}
