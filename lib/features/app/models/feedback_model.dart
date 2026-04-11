class FeedbackModel {
  const FeedbackModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.rating,
    required this.message,
    required this.createdAt,
  });

  final String? id;
  final String userId;
  final String userName;
  final String category;
  final int rating;
  final String message;
  final DateTime createdAt;

  FeedbackModel copyWith({String? id}) => FeedbackModel(
    id: id ?? this.id,
    userId: userId,
    userName: userName,
    category: category,
    rating: rating,
    message: message,
    createdAt: createdAt,
  );
}
