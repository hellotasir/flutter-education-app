import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/features/app/repositories/database_repository.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';

class FriendRequestRepository
    implements FirestoreRepository<FriendRequestModel> {
  const FriendRequestRepository();

  @override
  List<String> get collectionPath => ['friend_requests'];

  @override
  FriendRequestModel fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => FriendRequestModel.fromSnapshot(snapshot);

  @override
  Map<String, dynamic> toMap(FriendRequestModel model) => model.toMap();
}
