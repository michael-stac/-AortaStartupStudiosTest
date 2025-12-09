import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum TransactionStatus {
  pending,
  processing,
  completed,
  failed,
}

class Transaction {
  final String id;
  final double amount;
  final String recipientId;
  final String recipientName;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? errorMessage;
  final int retryCount;

  Transaction({
    String? id,
    required this.amount,
    required this.recipientId,
    required this.recipientName,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.errorMessage,
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4();

  Transaction copyWith({
    double? amount,
    String? recipientId,
    String? recipientName,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return Transaction(
      id: id,
      amount: amount ?? this.amount,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      status: TransactionStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      errorMessage: json['errorMessage'],
      retryCount: json['retryCount'] ?? 0,
    );
  }

  String get statusText {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  Color get statusColor {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.processing:
        return Colors.blue;
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }
}