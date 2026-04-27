import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa API Client
  final apiClient = ApiClient();
  await apiClient.initialize();

  runApp(OmniConnectApp(apiClient: apiClient));
}

class OmniConnectApp extends StatelessWidget {
  final ApiClient apiClient;

  const OmniConnectApp({
    Key? key,
    required this.apiClient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // API Client (singleton)
        Provider<ApiClient>.value(value: apiClient),

        // Auth Service (depende de ApiClient)
        ProxyProvider<ApiClient, AuthService>(
          update: (_, apiClient, __) => AuthService(apiClient: apiClient),
        ),

        // Auth Provider (depende de AuthService)
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
          ),
          update: (_, authService, previous) {
            return previous ?? AuthProvider(authService: authService);
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'OmniConnect Fitness',
        theme: AppTheme.darkTheme,
        routerConfig: AppRoutes.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
