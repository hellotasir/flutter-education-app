import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

enum ConversationType { individual, group }

enum FriendRequestStatus { pending, accepted, rejected, blocked }

enum MessageType { text, image, audio, video, file, system, call }

class ChatMessageModel {
  const ChatMessageModel({
    this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.type,
    required this.status,
    required this.sentAt,
    this.sentAtNanos = 0,
    this.readBy = const [],
    this.deliveredTo = const [],
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaDurationSeconds,
    this.mediaFileName,
    this.mediaFileSize,
    this.isDeleted = false,
  });

  final String? id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime sentAt;
  final int sentAtNanos;
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final int? mediaDurationSeconds;
  final String? mediaFileName;
  final int? mediaFileSize;
  final bool isDeleted;
  final List<String> readBy;
  final List<String> deliveredTo;

  int get sortKey =>
      sentAt.microsecondsSinceEpoch * 1000 + (sentAtNanos % 1000);

  factory ChatMessageModel.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parsedSentAt;
    int nanos = 0;

    final raw = data['sent_at'];
    if (raw is Timestamp) {
      parsedSentAt = raw.toDate();
      nanos = raw.nanoseconds;
    } else {
      parsedSentAt = DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    return ChatMessageModel(
      id: id ?? data['id'] as String?,
      conversationId: data['conversation_id'] as String? ?? '',
      senderId: data['sender_id'] as String? ?? '',
      senderUsername: data['sender_username'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      sentAt: parsedSentAt,
      sentAtNanos: nanos,
      readBy: List<String>.from(data['read_by'] ?? []),
      deliveredTo: List<String>.from(data['delivered_to'] ?? []),
      mediaUrl: data['media_url'] as String?,
      mediaThumbnailUrl: data['media_thumbnail_url'] as String?,
      mediaDurationSeconds: data['media_duration_seconds'] as int?,
      mediaFileName: data['media_file_name'] as String?,
      mediaFileSize: data['media_file_size'] as int?,
      isDeleted: data['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'conversation_id': conversationId,
    'sender_id': senderId,
    'sender_username': senderUsername,
    'content': content,
    'type': type.name,
    'status': status.name,
    'sent_at': Timestamp.fromDate(sentAt),
    'read_by': readBy,
    'delivered_to': deliveredTo,
    'media_url': mediaUrl,
    'media_thumbnail_url': mediaThumbnailUrl,
    'media_duration_seconds': mediaDurationSeconds,
    'media_file_name': mediaFileName,
    'media_file_size': mediaFileSize,
    'is_deleted': isDeleted,
  };

  ChatMessageModel copyWith({
    String? id,
    MessageStatus? status,
    List<String>? readBy,
    List<String>? deliveredTo,
    bool? isDeleted,
    String? content,
  }) => ChatMessageModel(
    id: id ?? this.id,
    conversationId: conversationId,
    senderId: senderId,
    senderUsername: senderUsername,
    content: content ?? this.content,
    type: type,
    status: status ?? this.status,
    sentAt: sentAt,
    sentAtNanos: sentAtNanos,
    readBy: readBy ?? this.readBy,
    deliveredTo: deliveredTo ?? this.deliveredTo,
    mediaUrl: mediaUrl,
    mediaThumbnailUrl: mediaThumbnailUrl,
    mediaDurationSeconds: mediaDurationSeconds,
    mediaFileName: mediaFileName,
    mediaFileSize: mediaFileSize,
    isDeleted: isDeleted ?? this.isDeleted,
  );
}

class MessageLimitException implements Exception {
  const MessageLimitException(this.message);
  final String message;

  @override
  String toString() => message;
}
