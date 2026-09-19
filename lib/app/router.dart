import 'package:go_router/go_router.dart';
import 'package:vera/features/auth/presentation/login_screen.dart';
import 'package:vera/features/auth/presentation/register_screen.dart';
import 'package:vera/features/home/presentation/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
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
      ],
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
