
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';

import '../repository/payment_reposiotry.dart';

class QueueProcessorService {
  final PaymentRepository _repository;
  final Connectivity _connectivity;
  Timer? _retryTimer;
  bool _isProcessing = false;

  QueueProcessorService({
    required PaymentRepository repository,
    Connectivity? connectivity,
  }) : _repository = repository,
        _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  Future<void> _initialize() async {
    /// Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    /// Initial queue check
    await Future.delayed(const Duration(seconds: 3));
    await _processQueueIfConnected();

    /// Set up periodic retry (every 30 seconds)
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processQueueIfConnected();
    });
  }

  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final isConnected = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);

    if (isConnected) {
      debugPrint('Connectivity restored - processing queue...');
      await Future.delayed(const Duration(seconds: 2)); // Wait for stable connection
      await _processQueueIfConnected();
    }
  }

  Future<void> _processQueueIfConnected() async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;

      final connectivity = await _connectivity.checkConnectivity();
      final isConnected = connectivity.isNotEmpty &&
          connectivity.any((r) => r != ConnectivityResult.none);

      if (isConnected) {
        /// Use the public method instead
        await _repository.processQueueManually();
      }
    } catch (e) {
      debugPrint('Queue processor error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> triggerManualProcessing() async {
    await _processQueueIfConnected();
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}