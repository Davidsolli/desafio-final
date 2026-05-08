import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/invite_code_screen.dart';
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
import '../screens/notifications_settings_screen.dart';
import '../screens/trainer/trainer_shell.dart';
import '../screens/trainer/trainer_home_screen.dart';
import '../screens/trainer/trainer_students_screen.dart';
import '../screens/trainer/trainer_student_detail.dart';
import '../screens/trainer/trainer_sheets.dart';
import '../screens/trainer/trainer_profile.dart';
import '../screens/trainer/generate_invite_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_pt_form_screen.dart';
import '../screens/admin/admin_pt_details_screen.dart';
import '../screens/admin/admin_settings_screen.dart';
import '../screens/admin/admin_student_form_screen.dart';

class AppRoutes {
  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String inviteCode = '/invite-code';
  static const String generateInvite = '/trainer/generate-invite';

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
  static const String adminDashboard = '/admin/trainers';
  static const String adminAddTrainer = '/admin/add-trainer';
  static const String adminEditTrainer = '/admin/edit-trainer';
  static const String adminTrainerStudents = '/admin/trainer-students';
  static const String adminAddStudent = '/admin/add-student';
  static const String adminEditStudent = '/admin/edit-student';
  static const String adminSettings = '/admin/settings';

  // Shared
  static const String notifications = '/notifications';
  static const String notificationsSettings = '/notifications-settings';

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
      GoRoute(
        path: notificationsSettings,
        builder: (context, state) => const NotificationsSettingsScreen(),
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
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: adminSettings,
            builder: (context, state) => const AdminSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: adminAddTrainer,
        builder: (context, state) => const AdminPTFormScreen(isEditing: false),
      ),
      GoRoute(
        path: adminEditTrainer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AdminPTFormScreen(
            isEditing: true,
            trainerId: extra?['trainerId'] as String?,
            trainerName: extra?['trainerName'] as String?,
            trainerEmail: extra?['trainerEmail'] as String?,
            trainerPhone: extra?['trainerPhone'] as String?,
          );
        },
      ),
      GoRoute(
        path: adminTrainerStudents,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final trainerId = extra?['trainerId'] as String? ?? 'unknown';
          final trainerName = extra?['trainerName'] as String? ?? 'Trainer';
          return AdminPTDetailsScreen(
            trainerId: trainerId,
            trainerName: trainerName,
          );
        },
      ),
      GoRoute(
        path: adminAddStudent,
        builder: (context, state) => const AdminPTFormScreen(isEditing: false),
      ),
      GoRoute(
        path: adminEditStudent,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AdminStudentFormScreen(
            isEditing: true,
            studentId: extra?['studentId'] as String?,
            studentName: extra?['studentName'] as String?,
            studentEmail: extra?['studentEmail'] as String?,
            studentPhone: extra?['studentPhone'] as String?,
          );
        },
      ),
    ],
  );
}
