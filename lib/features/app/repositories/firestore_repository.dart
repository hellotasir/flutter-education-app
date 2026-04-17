import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRepository<T> {
  List<String> get collectionPath;
  T fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot);
  Map<String, dynamic> toMap(T model);
}
