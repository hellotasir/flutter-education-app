import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

enum ConversationType { individual, group }

enum FriendRequestStatus { pending, accepted, rejected, blocked }

enum MessageType { text, image, audio, video, file, system, call }

enum CallType { audio, video }

enum CallStatus { ringing, ongoing, ended, missed, declined }

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
    this.callData,
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
  final CallMessageData? callData;
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
      callData: data['call_data'] != null
          ? CallMessageData.fromMap(data['call_data'] as Map<String, dynamic>)
          : null,
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
    'call_data': callData?.toMap(),
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
    callData: callData,
    isDeleted: isDeleted ?? this.isDeleted,
  );
}

class CallMessageData {
  const CallMessageData({
    required this.callType,
    required this.callStatus,
    this.durationSeconds,
  });

  final CallType callType;
  final CallStatus callStatus;
  final int? durationSeconds;

  factory CallMessageData.fromMap(Map<String, dynamic> data) => CallMessageData(
    callType: CallType.values.firstWhere(
      (e) => e.name == (data['call_type'] ?? 'audio'),
      orElse: () => CallType.audio,
    ),
    callStatus: CallStatus.values.firstWhere(
      (e) => e.name == (data['call_status'] ?? 'ended'),
      orElse: () => CallStatus.ended,
    ),
    durationSeconds: data['duration_seconds'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'call_type': callType.name,
    'call_status': callStatus.name,
    'duration_seconds': durationSeconds,
  };
}

class CallSession {
  const CallSession({
    this.id,
    required this.conversationId,
    required this.callerId,
    required this.callerUsername,
    required this.calleeId,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.channelId,
  });

  final String? id;
  final String conversationId;
  final String callerId;
  final String callerUsername;
  final String calleeId;
  final CallType callType;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? channelId;

  int get durationSeconds => answeredAt != null && endedAt != null
      ? endedAt!.difference(answeredAt!).inSeconds
      : 0;

  factory CallSession.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data()!;
    return CallSession(
      id: snap.id,
      conversationId: data['conversation_id'] as String? ?? '',
      callerId: data['caller_id'] as String? ?? '',
      callerUsername: data['caller_username'] as String? ?? '',
      calleeId: data['callee_id'] as String? ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.name == (data['call_type'] ?? 'audio'),
        orElse: () => CallType.audio,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answeredAt: (data['answered_at'] as Timestamp?)?.toDate(),
      endedAt: (data['ended_at'] as Timestamp?)?.toDate(),
      channelId: data['channel_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'conversation_id': conversationId,
    'caller_id': callerId,
    'caller_username': callerUsername,
    'callee_id': calleeId,
    'call_type': callType.name,
    'status': status.name,
    'created_at': Timestamp.fromDate(createdAt),
    'answered_at': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
    'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'channel_id': channelId,
  };

  CallSession copyWith({
    String? id,
    CallStatus? status,
    DateTime? answeredAt,
    DateTime? endedAt,
  }) => CallSession(
    id: id ?? this.id,
    conversationId: conversationId,
    callerId: callerId,
    callerUsername: callerUsername,
    calleeId: calleeId,
    callType: callType,
    status: status ?? this.status,
    createdAt: createdAt,
    answeredAt: answeredAt ?? this.answeredAt,
    endedAt: endedAt ?? this.endedAt,
    channelId: channelId,
  );
}

class MessageLimitException implements Exception {
  const MessageLimitException(this.message);
  final String message;

  @override
  String toString() => message;
}