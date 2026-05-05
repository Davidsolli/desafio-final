//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/invite_code_screen.dart';
import '../screens/student/home_screen.dart';
import '../screens/student/workouts_screen.dart';
import '../screens/student/nutrition_screen.dart';
import '../screens/student/logbook_screen.dart';
import '../screens/student/metrics_screen.dart';
import '../screens/student/goals_screen.dart';
import '../screens/student/chat_screen.dart';
import '../screens/student/profile_screen_new.dart';
import '../screens/notifications_screen.dart';
import '../screens/trainer/trainer_dashboard.dart';
import '../screens/trainer/trainer_student_detail.dart';
import '../screens/trainer/trainer_sheets.dart';
import '../screens/trainer/trainer_profile.dart';
import '../screens/trainer/generate_invite_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String inviteCode = '/invite-code';
  static const String generateInvite = '/trainer/generate-invite';
  static const String home = '/home';
  static const String workouts = '/workouts';
  static const String nutrition = '/nutrition';
  static const String logbook = '/logbook';
  static const String metrics = '/metrics';
  static const String goals = '/goals';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String notifications = '/notifications';

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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final invitationCode = extra?['invitationCode'] as String?;
          return RegisterScreen(invitationCode: invitationCode);
        },
      ),
      GoRoute(
        path: inviteCode,
        builder: (context, state) => const InviteCodeScreen(),
      ),
      GoRoute(
        path: generateInvite,
        builder: (context, state) => const GenerateInviteScreen(),
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
        builder: (context, state) => const ProfileScreenV2(),
      ),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/trainer/dashboard',
        builder: (context, state) => const TrainerDashboard(),
      ),
      GoRoute(
        path: '/trainer/student/:studentId',
        builder: (context, state) => TrainerStudentDetail(
          studentId: state.pathParameters['studentId'] ?? 's1',
        ),
      ),
      GoRoute(
        path: '/trainer/sheets',
        builder: (context, state) => const TrainerSheets(),
      ),
      GoRoute(
        path: '/trainer/profile',
        builder: (context, state) => const TrainerProfile(),
      ),
    ],
  );
}
