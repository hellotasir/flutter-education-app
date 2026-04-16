import 'package:flutter_education_app/features/subscription/models/subscription_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRepository {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  String get _requireUserId {
    final uid = _userId;
    if (uid == null) throw Exception('No authenticated user found.');
    return uid;
  }

  // ─── READ ───────────────────────────────────────────────────────────────────

  Future<List<SubscriptionTransaction>> getTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                SubscriptionTransaction.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<SubscriptionTransaction?> getTransaction(String id) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  Future<List<SubscriptionTransaction>> getSuccessfulTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .eq('status', 'success')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                SubscriptionTransaction.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch successful transactions: $e');
    }
  }

  Future<List<SubscriptionTransaction>> getFailedTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .eq('status', 'failed')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                SubscriptionTransaction.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch failed transactions: $e');
    }
  }

  // ─── DELETE ─────────────────────────────────────────────────────────────────

  /// Delete a single transaction by ID (only if it belongs to current user)
  Future<void> deleteTransaction(String id) async {
    try {
      final uid = _requireUserId;

      await _supabase.from('payments').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  /// Delete all transactions for current user
  Future<void> deleteAllTransactions() async {
    try {
      final uid = _requireUserId;

      await _supabase.from('payments').delete().eq('user_id', uid);
    } catch (e) {
      throw Exception('Failed to delete all transactions: $e');
    }
  }

  /// Delete all failed transactions for current user
  Future<void> deleteFailedTransactions() async {
    try {
      final uid = _requireUserId;

      await _supabase
          .from('payments')
          .delete()
          .eq('user_id', uid)
          .eq('status', 'failed');
    } catch (e) {
      throw Exception('Failed to delete failed transactions: $e');
    }
  }

  /// Delete multiple transactions by list of IDs (only if they belong to current user)
  Future<void> deleteTransactions(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      final uid = _requireUserId;

      await _supabase
          .from('payments')
          .delete()
          .eq('user_id', uid)
          .inFilter('id', ids);
    } catch (e) {
      throw Exception('Failed to delete transactions: $e');
    }
  }
}