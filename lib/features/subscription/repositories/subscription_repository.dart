import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_model.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_plan.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SubscriptionRepository {
  SubscriptionRepository({
    AuthRepository? authRepository,
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
  })  : _auth = authRepository ?? AuthRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _supabase = supabase ?? Supabase.instance.client;

  final AuthRepository _auth;
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  String get sslStoreId => dotenv.env['SSL_STORE_ID'] ?? '';
  String get sslStorePass => dotenv.env['SSL_STORE_PASS'] ?? '';

  String get _requireUserId {
    final uid = _auth.currentUser?.id;
    if (uid == null) throw Exception('No authenticated user found.');
    return uid;
  }

  Future<DocumentReference<Map<String, dynamic>>> _profileRef(String uid) async {
    final query = await _firestore
        .collection('profiles')
        .where('user_id', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Profile not found for user: $uid');
    return query.docs.first.reference;
  }
Future<String> createStripePaymentIntent({
    required int amount,
    required String currency,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-payment-intent',
      body: {'amount': amount, 'currency': currency},
    );

    if (response.status != 200) {
      throw Exception('Failed to create payment intent: ${response.data}');
    }

    final clientSecret = response.data['client_secret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('Invalid client secret returned from server.');
    }

    return clientSecret;
  }

  Future<SubscriptionTransaction> verifyAndActivateSSLCommerzSubscription({
    required SubscriptionPlan plan,
    required String transactionId,
    required String valId,
  }) async {
    return activateSubscription(
      plan: plan,
      gateway: 'sslcommerz',
      gatewayRef: valId,
    );
  }

  Future<SubscriptionModel?> getCurrentSubscription() async {
    final uid = _requireUserId;
    final ref = await _profileRef(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final sub = data?['subscription'];
    if (sub == null) return null;
    return SubscriptionModel.fromMap(sub as Map<String, dynamic>);
  }

  Future<bool> isSubscriptionActive() async {
    try {
      final sub = await getCurrentSubscription();
      return sub?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<SubscriptionTransaction> activateSubscription({
    required SubscriptionPlan plan,
    required String gateway,
    String? gatewayRef,
  }) async {
    final uid = _requireUserId;
    final transactionId = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: plan.durationDays));

    final tx = SubscriptionTransaction(
      id: transactionId,
      userId: uid,
      planId: plan.id,
      planName: plan.name,
      amount: plan.price,
      currency: 'USD',
      gateway: gateway,
      gatewayRef: gatewayRef,
      status: 'success',
      createdAt: now,
    );

    final subscription = SubscriptionModel(
      planId: plan.id,
      planName: plan.name,
      status: 'active',
      startedAt: now,
      expiresAt: expiresAt,
      paymentGateway: gateway,
      updatedAt: now,
    );

    await _recordPaymentToSupabase(tx);
    await _writeSubscriptionToProfile(uid, subscription);

    return tx;
  }

  Future<void> recordFailedPayment({
    required SubscriptionPlan plan,
    required String gateway,
    required String status,
    String? errorMessage,
    String? gatewayRef,
  }) async {
    final uid = _requireUserId;
    final tx = SubscriptionTransaction(
      id: _uuid.v4(),
      userId: uid,
      planId: plan.id,
      planName: plan.name,
      amount: plan.price,
      currency: 'USD',
      gateway: gateway,
      gatewayRef: gatewayRef,
      status: status,
      errorMessage: errorMessage,
      createdAt: DateTime.now(),
    );
    await _recordPaymentToSupabase(tx);
  }

  Future<void> cancelSubscription() async {
    final uid = _requireUserId;
    final ref = await _profileRef(uid);
    await ref.update({
      'subscription.status': 'cancelled',
      'subscription.updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _recordPaymentToSupabase(SubscriptionTransaction tx) async {
    try {
      await _supabase.from('payments').insert(tx.toMap());
    } catch (e) {
      debugPrint('[SubscriptionRepository] Supabase payment record failed: $e');
      rethrow;
    }
  }

  Future<void> _writeSubscriptionToProfile(
    String uid,
    SubscriptionModel subscription,
  ) async {
    try {
      final ref = await _profileRef(uid);
      await ref.update({'subscription': subscription.toMap()});
    } catch (e) {
      debugPrint('[SubscriptionRepository] Firestore subscription update failed: $e');
      rethrow;
    }
  }
}