import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/repositories/firestore_repository.dart';

class ProfileRepository implements FirestoreRepository<ProfileModel> {
  const ProfileRepository();

  @override
  List<String> get collectionPath => ['profiles'];

  @override
  ProfileModel fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      ProfileModel.fromFirestore(snapshot.data()!);

  @override
  Map<String, dynamic> toMap(ProfileModel model) => {
    ...model.toFirestore(),
    'usernameLower': ProfileModel.encodeValue(model.username.toLowerCase()),
  };
}
