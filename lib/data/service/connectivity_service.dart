import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _isListening = false;

  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    if (!_isListening) {
      _isListening = true;
    }
    return _connectivity.onConnectivityChanged;
  }

  Future<List<ConnectivityResult>> checkConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      return [ConnectivityResult.none];
    }
  }

  /// Add a method to manually trigger connectivity check
  Future<bool> isConnected() async {
    final results = await checkConnectivity();
    return results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
  }
}