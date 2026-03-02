/// Chat message for the chat-first UI. Can be user or assistant (coach).
enum ChatMessageRole { user, assistant }

class ChatMessageModel {
  final String id;
  final String text;
  final ChatMessageRole role;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
  });
}
