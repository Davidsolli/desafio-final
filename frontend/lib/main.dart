import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/goal_service.dart';
import 'services/logbook_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/logbook_provider.dart';

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
          update: (_, apiClient, _) => AuthService(apiClient: apiClient),
        ),

        // User Service (depende de ApiClient)
        ProxyProvider<ApiClient, UserService>(
          update: (_, apiClient, _) => UserService(apiClient: apiClient),
        ),

        // Goal Service (depende de ApiClient)
        ProxyProvider<ApiClient, GoalService>(
          update: (_, apiClient, _) => GoalService(apiClient: apiClient),
        ),

        // Logbook Service (depende de ApiClient)
        ProxyProvider<ApiClient, LogbookService>(
          update: (_, apiClient, _) => LogbookService(apiClient: apiClient),
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

        // User Provider (depende de UserService)
        ChangeNotifierProxyProvider<UserService, UserProvider>(
          create: (context) => UserProvider(
            userService: context.read<UserService>(),
          ),
          update: (_, userService, previous) {
            return previous ?? UserProvider(userService: userService);
          },
        ),

        // Goal Provider (depende de GoalService)
        ChangeNotifierProxyProvider<GoalService, GoalProvider>(
          create: (context) => GoalProvider(
            goalService: context.read<GoalService>(),
          ),
          update: (_, goalService, previous) {
            return previous ?? GoalProvider(goalService: goalService);
          },
        ),

        // Logbook Provider (depende de LogbookService)
        ChangeNotifierProxyProvider<LogbookService, LogbookProvider>(
          create: (context) => LogbookProvider(
            logbookService: context.read<LogbookService>(),
          ),
          update: (_, logbookService, previous) {
            return previous ?? LogbookProvider(logbookService: logbookService);
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
