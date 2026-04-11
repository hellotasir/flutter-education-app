import 'package:cloud_firestore/cloud_firestore.dart';

class UserPresenceModel {
  const UserPresenceModel({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
  });

  final String userId;
  final bool isOnline;
  final DateTime lastSeen;

  factory UserPresenceModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? {};
    return UserPresenceModel(
      userId: snap.id,
      isOnline: data['is_online'] as bool? ?? false,
      lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'is_online': isOnline,
    'last_seen': Timestamp.fromDate(lastSeen),
  };
}
