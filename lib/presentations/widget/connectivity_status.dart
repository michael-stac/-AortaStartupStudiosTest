import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/connectivity_provider.dart';

class ConnectivityStatus extends StatelessWidget {
  const ConnectivityStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Icon(
        connectivityProvider.isConnected ? Icons.wifi : Icons.wifi_off,
        color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
      ),
    );
  }
}