class PaymentHistoryModel {
  String id;
  String userId;
  String productTitle;
  double amount;
  DateTime date;
  String status;

  PaymentHistoryModel({
    required this.id,
    required this.amount,
    required this.date,
    required this.status,
    required this.userId,
    required this.productTitle,
  });

  factory PaymentHistoryModel.fromMap(Map<String, dynamic> map) {
    return PaymentHistoryModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'unknown',
      userId: map['user_id'] ?? '',
      productTitle: map['product_title'] ?? '',
    );
  }
}
