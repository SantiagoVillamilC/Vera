import 'package:go_router/go_router.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/backup_codes_screen.dart';
import 'package:vera/features/auth/presentation/login_screen.dart';
import 'package:vera/features/auth/presentation/recovery_screen.dart';
import 'package:vera/features/auth/presentation/register_screen.dart';
import 'package:vera/features/home/presentation/enviar_llave_screen.dart';
import 'package:vera/features/home/presentation/enviar_screen.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/home_screen.dart';
import 'package:vera/features/home/presentation/recargar_screen.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

bool _isPublicLocation(String path) =>
    path == '/login' ||
    path.startsWith('/login/') ||
    path == '/register' ||
    path.startsWith('/register/');

/// Router de la app. La sesión se lee del [SessionNotifier] (cargado una sola
/// vez al arrancar), nunca del almacenamiento seguro en cada redirect.
/// Los parámetros opcionales inyectan dependencias al Home (pruebas de widget),
/// por defecto las reales.
GoRouter buildRouter(
  SessionNotifier session, {
  AuthRepository? authRepository,
  SessionStore? sessionStore,
  NucleoRepository? nucleoRepository,
}) => GoRouter(
  initialLocation: '/login',
  refreshListenable: session,
  redirect: (context, state) {
    final path = state.uri.path;
    if (!session.authenticated) {
      return _isPublicLocation(path) ? null : '/login';
    }
    return path == '/login' ? '/home' : null;
  },
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
      builder: (context, state) => HomeScreen(
        authRepository: authRepository,
        session: sessionStore,
        repository: nucleoRepository,
      ),
    ),
    GoRoute(
      path: '/enviar',
      builder: (context, state) => const EnviarScreen(),
    ),
    GoRoute(
      path: '/enviar-llave',
      builder: (context, state) =>
          EnviarLlaveScreen(repository: nucleoRepository),
    ),
    GoRoute(
      path: '/recargar',
      builder: (context, state) => RecargarScreen(
        repository: nucleoRepository,
        session: sessionStore,
      ),
    ),
    GoRoute(
      path: '/estadisticas',
      builder: (context, state) => const EstadisticasScreen(),
    ),
  ],
);

final appRouter = buildRouter(appSession);
