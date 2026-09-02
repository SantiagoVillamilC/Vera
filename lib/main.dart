import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';

void main() => runApp(const CentinelaApp());

class CentinelaApp extends StatelessWidget {
  const CentinelaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Centinela',
        theme: AppTheme.light,
        home: const LoginScreen(),
      );
}
