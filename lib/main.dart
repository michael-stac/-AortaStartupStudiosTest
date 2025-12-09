import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:offlinepayment/presentations/screesn/home_screen.dart';
import 'package:provider/provider.dart';

import 'core/utils/connectivity_helper.dart';
import 'data/repository/payment_reposiotry.dart';
import 'data/service/local_storage.dart';
import 'data/service/mock_api_service.dart';
import 'domain/providers/connectivity_provider.dart';
import 'domain/providers/payment_provider.dart';
import 'presentations/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityHelper.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) {
            final provider = ConnectivityProvider();

            provider.initialize();
            return provider;
          },
        ),

        Provider<PaymentRepository>(
          create: (_) => PaymentRepository(
            apiService: MockApiService(),
            storageService: LocalStorageService(),
            connectivity: Connectivity(),
          ),
          dispose: (_, repository) => repository.dispose(),
        ),

        ChangeNotifierProxyProvider<PaymentRepository, PaymentProvider>(
          create: (context) {
            final repository = context.read<PaymentRepository>();
            final provider = PaymentProvider(repository: repository);

            provider.initialize();
            return provider;
          },
          update: (context, repository, previous) {
            return previous ?? PaymentProvider(repository: repository)
              ..initialize();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Resilient Euro Transfer',
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
