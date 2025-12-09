import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';

class LocalStorageService {
  static const String _balanceKey = 'server_balance';
  static const String _pendingTransactionsKey = 'pending_transactions';
  static const String _allTransactionsKey = 'all_transactions';

  Future<void> saveBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_balanceKey, balance);
  }

  Future<double?> loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_balanceKey);
  }

  Future<void> savePendingTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_pendingTransactionsKey, json.encode(jsonList));
  }

  Future<List<Transaction>> loadPendingTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingTransactionsKey);

    if (jsonString == null) return [];

    try {
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAllTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_allTransactionsKey, json.encode(jsonList));
  }

  Future<List<Transaction>> loadAllTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_allTransactionsKey);

    if (jsonString == null) return [];

    try {
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_balanceKey);
    await prefs.remove(_pendingTransactionsKey);
    await prefs.remove(_allTransactionsKey);
  }
}