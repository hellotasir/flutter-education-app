class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String duration;
  final int durationDays;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.durationDays,
    required this.features,
  });

  static const monthly = SubscriptionPlan(
    id: 'plan_monthly',
    name: 'Monthly Plan',
    price: 9.99,
    duration: 'month',
    durationDays: 30,
    features: ['Verified Badge', 'Video & Voice Call', 'Distance Tracker'],
  );

  static const yearly = SubscriptionPlan(
    id: 'plan_yearly',
    name: 'Yearly Plan',
    price: 99.99,
    duration: 'year',
    durationDays: 365,
    features: ['Verified Badge', 'Video & Voice Call', 'Distance Tracker'],
  );

  static List<SubscriptionPlan> get all => [monthly, yearly];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'duration': duration,
    'duration_days': durationDays,
    'features': features,
  };

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) => SubscriptionPlan(
    id: map['id'] as String,
    name: map['name'] as String,
    price: (map['price'] as num).toDouble(),
    duration: map['duration'] as String,
    durationDays: map['duration_days'] as int,
    features: List<String>.from(map['features'] as List),
  );

  @override
  String toString() =>
      'SubscriptionPlan(id: $id, name: $name, price: $price, duration: $duration)';
}