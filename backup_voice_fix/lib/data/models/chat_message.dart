class ChatMessage {
  final String id;
  final String role; // 'user' | 'model' | 'system'
  final String text;
  final DateTime time;
  final bool failed;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.failed = false,
  });

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'time': time.millisecondsSinceEpoch,
        'failed': failed,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        text: json['text'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
        failed: json['failed'] as bool? ?? false,
      );

  ChatMessage copyWith({String? text, bool? failed, String? role}) => ChatMessage(
        id: id,
        role: role ?? this.role,
        text: text ?? this.text,
        time: time,
        failed: failed ?? this.failed,
      );
}
