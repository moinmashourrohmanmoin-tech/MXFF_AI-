import '../../core/constants.dart';

class AppSettings {
  final String geminiApiKey;
  final String model;
  final String systemInstruction;
  final String language; // 'auto' | 'bn' | 'en'
  final double speechRate; // 0.0 - 1.0 (flutter_tts scale)
  final double ttsVolume; // 0.0 - 1.0
  final double ttsPitch; // 0.5 - 2.0
  final bool wakeWordEnabled;
  final String wakePhrase;
  final bool orbAnimationEnabled;
  final bool overlayEnabled;

  const AppSettings({
    this.geminiApiKey = '',
    this.model = kDefaultGeminiModel,
    this.systemInstruction = kDefaultSystemInstruction,
    this.language = 'auto',
    this.speechRate = 0.48,
    this.ttsVolume = 1.0,
    this.ttsPitch = 1.0,
    this.wakeWordEnabled = false,
    this.wakePhrase = 'MXFF',
    this.orbAnimationEnabled = true,
    this.overlayEnabled = false,
  });

  String get speechLocale {
    switch (language) {
      case 'bn':
        return 'bn-BD';
      case 'en':
        return 'en-US';
      default:
        return '';
    } // '' -> device default
  }

  AppSettings copyWith({
    String? geminiApiKey,
    String? model,
    String? systemInstruction,
    String? language,
    double? speechRate,
    double? ttsVolume,
    double? ttsPitch,
    bool? wakeWordEnabled,
    String? wakePhrase,
    bool? orbAnimationEnabled,
    bool? overlayEnabled,
  }) =>
      AppSettings(
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        model: model ?? this.model,
        systemInstruction: systemInstruction ?? this.systemInstruction,
        language: language ?? this.language,
        speechRate: speechRate ?? this.speechRate,
        ttsVolume: ttsVolume ?? this.ttsVolume,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
        wakePhrase: wakePhrase ?? this.wakePhrase,
        orbAnimationEnabled: orbAnimationEnabled ?? this.orbAnimationEnabled,
        overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      );

  Map<String, dynamic> toJson() => {
        'geminiApiKey': geminiApiKey,
        'model': model,
        'systemInstruction': systemInstruction,
        'language': language,
        'speechRate': speechRate,
        'ttsVolume': ttsVolume,
        'ttsPitch': ttsPitch,
        'wakeWordEnabled': wakeWordEnabled,
        'wakePhrase': wakePhrase,
        'orbAnimationEnabled': orbAnimationEnabled,
        'overlayEnabled': overlayEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        geminiApiKey: json['geminiApiKey'] as String? ?? '',
        model: json['model'] as String? ?? kDefaultGeminiModel,
        systemInstruction:
            json['systemInstruction'] as String? ?? kDefaultSystemInstruction,
        language: json['language'] as String? ?? 'auto',
        speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.48,
        ttsVolume: (json['ttsVolume'] as num?)?.toDouble() ?? 1.0,
        ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
        wakeWordEnabled: json['wakeWordEnabled'] as bool? ?? false,
        wakePhrase: json['wakePhrase'] as String? ?? 'MXFF',
        orbAnimationEnabled: json['orbAnimationEnabled'] as bool? ?? true,
        overlayEnabled: json['overlayEnabled'] as bool? ?? false,
      );
}
