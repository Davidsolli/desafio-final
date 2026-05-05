import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/student/student_shell.dart';
import '../screens/student/home_screen.dart';
import '../screens/student/workouts_screen.dart';
import '../screens/student/nutrition_screen.dart';
import '../screens/student/logbook_screen.dart';
import '../screens/student/metrics_screen.dart';
import '../screens/student/goals_screen.dart';
import '../screens/student/chat_screen.dart';
import '../screens/student/profile_screen_new.dart';
import '../screens/notifications_screen.dart';
import '../screens/trainer/trainer_shell.dart';
import '../screens/trainer/trainer_home_screen.dart';
import '../screens/trainer/trainer_students_screen.dart';
import '../screens/trainer/trainer_student_detail.dart';
import '../screens/trainer/trainer_sheets.dart';
import '../screens/trainer/trainer_profile.dart';
import '../screens/admin/admin_dashboard.dart';

class AppRoutes {
  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Student
  static const String home = '/home';
  static const String workouts = '/workouts';
  static const String nutrition = '/nutrition';
  static const String logbook = '/logbook';
  static const String metrics = '/metrics';
  static const String goals = '/goals';
  static const String chat = '/chat';
  static const String profile = '/profile';

  // Trainer
  static const String trainerHome = '/trainer/home';
  static const String trainerStudents = '/trainer/students';
  static const String trainerStudent = '/trainer/student/:studentId';
  static const String trainerSheets = '/trainer/sheets';
  static const String trainerProfile = '/trainer/profile';

  // Admin
  static const String adminDashboard = '/admin/dashboard';

  // Shared
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
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
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
        ],
      ),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => TrainerShell(child: child),
        routes: [
          GoRoute(
            path: '/trainer/home',
            builder: (context, state) => const TrainerHomeScreen(),
          ),
          GoRoute(
            path: '/trainer/students',
            builder: (context, state) => const TrainerStudentsScreen(),
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
      ),
      GoRoute(
        path: '/trainer/student/:studentId',
        builder: (context, state) => TrainerStudentDetail(
          studentId: state.pathParameters['studentId'] ?? 's1',
        ),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPlaceholder(),
      ),
    ],
  );
}
