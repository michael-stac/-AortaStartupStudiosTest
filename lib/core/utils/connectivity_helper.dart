
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Process;

class ConnectivityHelper {
  static bool _isSimulator = false;

  static Future<void> init() async {
    // Check if running on simulator/emulator
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        // Simple check for simulator - emulators often have specific model names
        if (Platform.isIOS) {
          final process = await Process.run('sysctl', ['hw.model']);
          final output = process.stdout.toString().toLowerCase();
          _isSimulator = output.contains('simulator') ||
              output.contains('virtual');
        } else if (Platform.isAndroid) {
          final process = await Process.run('getprop', ['ro.product.model']);
          final output = process.stdout.toString().toLowerCase();
          _isSimulator = output.contains('sdk') ||
              output.contains('emulator') ||
              output.contains('google_sdk');
        }
      } catch (e) {
        print('⚠️ Could not determine if simulator: $e');
      }
    }

    print('📱 Running on simulator? $_isSimulator');
  }

  static bool isConnected(List<ConnectivityResult> results) {
    print('🔍 Connectivity results: $results');

    // On simulator, we might have internet even though connectivity shows none
    if (_isSimulator || kIsWeb) {
      print('📱 Running on simulator/web - assuming connected for queue processing');
      // We'll rely on the actual internet test in PaymentRepository
      return true; // Always return true to allow queue processing
    }

    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasMobile = results.contains(ConnectivityResult.mobile);
    final hasEthernet = results.contains(ConnectivityResult.ethernet);
    final hasVpn = results.contains(ConnectivityResult.vpn);
    final hasBluetooth = results.contains(ConnectivityResult.bluetooth);

    print('🔍 Details - WiFi: $hasWifi, Mobile: $hasMobile, Ethernet: $hasEthernet');
    print('🔍 Details - VPN: $hasVpn, Bluetooth: $hasBluetooth');

    final connected = results.isNotEmpty &&
        (hasWifi || hasMobile || hasEthernet || hasVpn || hasBluetooth);

    print('🔍 Is connected? $connected');
    return connected;
  }

  static bool isWifiConnected(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi);
  }

  static bool isMobileConnected(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile);
  }

  static String getConnectionStatus(List<ConnectivityResult> results) {
    if (!isConnected(results)) return 'Offline';
    if (isWifiConnected(results)) return 'WiFi';
    if (isMobileConnected(results)) return 'Mobile Data';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
    return 'Other';
  }
}