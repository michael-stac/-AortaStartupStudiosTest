import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/utils/connectivity_helper.dart';



class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity;

  List<ConnectivityResult> _connectivityResults = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;

  ConnectivityProvider({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  List<ConnectivityResult> get connectivityResults => _connectivityResults;
  bool get isConnected => ConnectivityHelper.isConnected(_connectivityResults);
  String get connectionStatus => ConnectivityHelper.getConnectionStatus(_connectivityResults);

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('ConnectivityProvider already initialized, forcing refresh...');
    }

    try {
      debugPrint('Initializing ConnectivityProvider...');

      /// Cancel existing subscription if any
      await _subscription?.cancel();

      /// Get initial connectivity
      _connectivityResults = await _connectivity.checkConnectivity();
      debugPrint(' Initial connectivity: $_connectivityResults');
      notifyListeners();

      // Listen for changes with error handling
      _subscription = _connectivity.onConnectivityChanged.listen(
            (results) {
              debugPrint('Connectivity changed: $results');
          _connectivityResults = results;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
          // Try to restart the listener
          _restartListener();
        },
        cancelOnError: false,
      );

      _isInitialized = true;
      debugPrint('ConnectivityProvider initialized');
    } catch (e) {
      debugPrint('Error initializing ConnectivityProvider: $e');
    }
  }

  Future<void> _restartListener() async {
    debugPrint('Restarting connectivity listener...');
    await _subscription?.cancel();
    await Future.delayed(const Duration(seconds: 1));
    await initialize();
  }

  /// Force refresh connectivity status
  Future<void> refresh() async {
    try {
      debugPrint('Forcing connectivity refresh...');
      _connectivityResults = await _connectivity.checkConnectivity();
      debugPrint('Refreshed connectivity: $_connectivityResults');
      notifyListeners();
    } catch (e) {
      print('⚠️ Error refreshing connectivity: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing ConnectivityProvider...');
    _subscription?.cancel();
    _isInitialized = false;
    super.dispose();
  }
}