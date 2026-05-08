import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/goal_service.dart';
import 'services/logbook_service.dart';
import 'services/nutrition_service.dart';
import 'services/workout_sheet_service.dart';
import 'services/invitation_service.dart';
import 'services/admin_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/logbook_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/workout_sheet_provider.dart';
import 'providers/invitation_provider.dart';
import 'providers/admin_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa API Client
  final apiClient = ApiClient();
  await apiClient.initialize();

  // Inicializa ThemeProvider (carrega preferência salva)
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(OmniConnectApp(apiClient: apiClient, themeProvider: themeProvider));
}

class OmniConnectApp extends StatelessWidget {
  final ApiClient apiClient;
  final ThemeProvider themeProvider;

  const OmniConnectApp({
    Key? key,
    required this.apiClient,
    required this.themeProvider,
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

        // Nutrition Service (depende de ApiClient)
        ProxyProvider<ApiClient, NutritionService>(
          update: (_, apiClient, _) => NutritionService(apiClient: apiClient),
        ),

        // WorkoutSheet Service (depende de ApiClient)
        ProxyProvider<ApiClient, WorkoutSheetService>(
          update: (_, apiClient, _) => WorkoutSheetService(apiClient: apiClient),
        ),

        // Invitation Service (depende de ApiClient)
        ProxyProvider<ApiClient, InvitationService>(
          update: (_, apiClient, _) => InvitationService(apiClient: apiClient),
        ),

        // Admin Service (depende de ApiClient)
        ProxyProvider<ApiClient, AdminService>(
          update: (_, apiClient, _) => AdminService(apiClient: apiClient),
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

        // Nutrition Provider (depende de NutritionService)
        ChangeNotifierProxyProvider<NutritionService, NutritionProvider>(
          create: (context) => NutritionProvider(
            nutritionService: context.read<NutritionService>(),
          ),
          update: (_, nutritionService, previous) {
            return previous ?? NutritionProvider(nutritionService: nutritionService);
          },
        ),

        // WorkoutSheet Provider (depende de WorkoutSheetService)
        ChangeNotifierProxyProvider<WorkoutSheetService, WorkoutSheetProvider>(
          create: (context) => WorkoutSheetProvider(
            workoutSheetService: context.read<WorkoutSheetService>(),
          ),
          update: (_, workoutSheetService, previous) {
            return previous ?? WorkoutSheetProvider(workoutSheetService: workoutSheetService);
          },
        ),

        // Invitation Provider (depende de ApiClient)
        ChangeNotifierProxyProvider<ApiClient, InvitationProvider>(
          create: (context) => InvitationProvider(
            apiClient: context.read<ApiClient>(),
          ),
          update: (_, apiClient, previous) {
            return previous ?? InvitationProvider(apiClient: apiClient);
          },
        ),

        // Admin Provider (depende de AdminService)
        ChangeNotifierProxyProvider<AdminService, AdminProvider>(
          create: (context) => AdminProvider(
            service: context.read<AdminService>(),
          ),
          update: (_, adminService, previous) {
            return previous ?? AdminProvider(service: adminService);
          },
        ),
      ],
      child: ChangeNotifierProvider.value(
        value: themeProvider,
        child: Consumer<ThemeProvider>(
          builder: (_, provider, __) => MaterialApp.router(
            title: 'FitLoop',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode,
            routerConfig: AppRoutes.router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
