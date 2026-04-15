class SubscriptionTransaction {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final double amount;
  final String currency;
  final String gateway;
  final String? gatewayRef;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;

  const SubscriptionTransaction({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.gateway,
    this.gatewayRef,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isSuccess => status == 'success';

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'plan_id': planId,
    'plan_name': planName,
    'amount': amount,
    'currency': currency,
    'gateway': gateway,
    'gateway_ref': gatewayRef,
    'status': status,
    'error_message': errorMessage,
    'created_at': createdAt.toIso8601String(),
  };

  factory SubscriptionTransaction.fromMap(Map<String, dynamic> map) =>
      SubscriptionTransaction(
        id: map['id'] as String,
        userId: map['user_id'] as String? ?? '',
        planId: map['plan_id'] as String? ?? '',
        planName: map['plan_name'] as String? ?? '',
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'USD',
        gateway: map['gateway'] as String? ?? '',
        gatewayRef: map['gateway_ref'] as String?,
        status: map['status'] as String? ?? 'error',
        errorMessage: map['error_message'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );

  @override
  String toString() =>
      'SubscriptionTransaction(id: $id, planName: $planName, '
      'amount: $amount, status: $status, gateway: $gateway)';
}
