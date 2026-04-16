import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/features/app/models/feedback_model.dart';
import 'package:flutter_education_app/others/repositories/firestore_repository.dart';

class FeedbackRepository implements FirestoreRepository<FeedbackModel> {
  @override
  List<String> get collectionPath => ['feedback'];

  @override
  FeedbackModel fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return FeedbackModel(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Anonymous',
      category: data['category'] as String? ?? 'general',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap(FeedbackModel model) => {
    'userId': model.userId,
    'userName': model.userName,
    'category': model.category,
    'rating': model.rating,
    'message': model.message,
    'createdAt': Timestamp.fromDate(model.createdAt),
  };
}
