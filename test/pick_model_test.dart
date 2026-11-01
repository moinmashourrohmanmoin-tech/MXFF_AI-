import 'package:flutter_test/flutter_test.dart';

import 'package:mxff_ai/services/gemini/gemini_service.dart';

void main() {
  test('picks the configured model when it is still available', () {
    final models = ['gemini-3-pro', 'gemini-3-flash', 'gemini-2.5-flash'];
    expect(pickBestGeminiModel(models, 'gemini-2.5-flash'),
        'gemini-2.5-flash');
  });

  test('falls back to a working flash model when the preferred one is gone',
      () {
    final models = ['gemini-3-pro', 'gemini-3-flash', 'gemini-3-flash-lite'];
    expect(pickBestGeminiModel(models, 'gemini-2.5-flash'), 'gemini-3-flash');
  });

  test('prefers flash over pro when resolving from "auto"', () {
    final models = ['gemini-3-pro', 'gemini-3-flash'];
    expect(pickBestGeminiModel(models, ''), 'gemini-3-flash');
  });

  test('ignores non-gemini entries first and returns something usable', () {
    final models = ['chat-bison-001', 'gemma-3-27b'];
    expect(pickBestGeminiModel(models, 'auto'), 'gemma-3-27b');
  });

  test('returns null for an empty list', () {
    expect(pickBestGeminiModel([], 'auto'), isNull);
  });
}
