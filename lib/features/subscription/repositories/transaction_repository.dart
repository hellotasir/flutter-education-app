import 'package:flutter_education_app/features/subscription/models/subscription_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRepository {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<List<SubscriptionTransaction>> getTransactions() async {
    final uid = _userId;
    if (uid == null) return [];

    final response = await _supabase
        .from('payments')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => SubscriptionTransaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionTransaction?> getTransaction(String id) async {
    final uid = _userId;
    if (uid == null) return null;

    final response = await _supabase
        .from('payments')
        .select()
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();

    if (response == null) return null;
    return SubscriptionTransaction.fromMap(response);
  }

  Future<List<SubscriptionTransaction>> getSuccessfulTransactions() async {
    final uid = _userId;
    if (uid == null) return [];

    final response = await _supabase
        .from('payments')
        .select()
        .eq('user_id', uid)
        .eq('status', 'success')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => SubscriptionTransaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}