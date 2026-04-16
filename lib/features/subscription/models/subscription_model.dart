class SubscriptionModel {
  final String planId;
  final String planName;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String? paymentGateway;
  final DateTime updatedAt;

  const SubscriptionModel({
    required this.planId,
    required this.planName,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    this.paymentGateway,
    required this.updatedAt,
  });

  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() => {
    'plan_id': planId,
    'plan_name': planName,
    'status': status,
    'started_at': startedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'payment_gateway': paymentGateway,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) => SubscriptionModel(
    planId: map['plan_id'] as String? ?? '',
    planName: map['plan_name'] as String? ?? '',
    status: map['status'] as String? ?? 'expired',
    startedAt: _parseDate(map['started_at']),
    expiresAt: _parseDate(map['expires_at']),
    paymentGateway: map['payment_gateway'] as String?,
    updatedAt: _parseDate(map['updated_at']),
  );

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  SubscriptionModel copyWith({
    String? planId,
    String? planName,
    String? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    String? paymentGateway,
    DateTime? updatedAt,
  }) => SubscriptionModel(
    planId: planId ?? this.planId,
    planName: planName ?? this.planName,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    paymentGateway: paymentGateway ?? this.paymentGateway,
    updatedAt: updatedAt ?? this.updatedAt,
  );

}