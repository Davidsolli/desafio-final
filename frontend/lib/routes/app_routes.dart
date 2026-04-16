//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/student/home_screen.dart';
import '../screens/student/workouts_screen.dart';
import '../screens/student/nutrition_screen.dart';
import '../screens/student/logbook_screen.dart';
import '../screens/student/metrics_screen.dart';
import '../screens/student/goals_screen.dart';
import '../screens/student/chat_screen.dart';
import '../screens/student/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String workouts = '/workouts';
  static const String nutrition = '/nutrition';
  static const String logbook = '/logbook';
  static const String metrics = '/metrics';
  static const String goals = '/goals';
  static const String chat = '/chat';
  static const String profile = '/profile';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: workouts,
        builder: (context, state) => const WorkoutsScreen(),
      ),
      GoRoute(
        path: nutrition,
        builder: (context, state) => const NutritionScreen(),
      ),
      GoRoute(
        path: logbook,
        builder: (context, state) => const LogbookScreen(),
      ),
      GoRoute(
        path: metrics,
        builder: (context, state) => const MetricsScreen(),
      ),
      GoRoute(
        path: goals,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: chat,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}
