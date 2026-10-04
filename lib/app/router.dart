import 'package:go_router/go_router.dart';
import 'package:vera/features/auth/presentation/backup_codes_screen.dart';
import 'package:vera/features/auth/presentation/login_screen.dart';
import 'package:vera/features/auth/presentation/recovery_screen.dart';
import 'package:vera/features/auth/presentation/register_screen.dart';
import 'package:vera/features/home/presentation/enviar_screen.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home', // TODO: revertir a '/login' antes de producción
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
      routes: [
        GoRoute(
          path: 'pin',
          builder: (context, state) => PinScreen(phone: state.extra as String),
        ),
        GoRoute(
          path: 'otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return OtpLoginScreen(
              phone: extra['phone'] as String,
              challengeId: extra['challengeId'] as String,
            );
          },
        ),
        GoRoute(
          path: 'recovery',
          builder: (context, state) => const RecoveryScreen(),
          routes: [
            GoRoute(
              path: 'otp',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>;
                return RecoveryOtpScreen(
                  correo: extra['correo'] as String,
                  challengeId: extra['challengeId'] as String,
                );
              },
            ),
            GoRoute(
              path: 'new-pin',
              builder: (context, state) => NewPinScreen(resetToken: state.extra as String),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/register/backup-codes',
      builder: (context, state) {
        final codes = state.extra is List<String> ? state.extra as List<String> : const <String>[];
        return BackupCodesScreen(codes: codes);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/enviar',
      builder: (context, state) => const EnviarScreen(),
    ),
    GoRoute(
      path: '/estadisticas',
      builder: (context, state) => const EstadisticasScreen(),
    ),
  ],
);
