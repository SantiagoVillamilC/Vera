import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/theme/paleta_vera.dart';

abstract final class AppColors {
  // Backgrounds
  static const background = Color(0xFF0A111C);
  static const surface = Color(0xFF131D2C);
  static const surfaceVariant = Color(0xFF1A2639);
  static const surfaceGlass = Color(0x1AFFFFFF);

  // Brand gradient (azul de VeraDark)
  static const gradientStart = Color(0xFF6CB6F2);
  static const gradientMid = Color(0xFF2F78C9);
  static const gradientEnd = Color(0xFF214E8C);

  // Accents
  static const accent = Color(0xFF6CB6F2);
  static const accentGreen = Color(0xFF55D693);
  static const accentPink = Color(0xFFF07A9C);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9AA9BD);
  static const textMuted = Color(0xFF5E6E85);

  // Borders
  static const border = Color(0xFF223047);
  static const borderGlass = Color(0x33FFFFFF);
  static const borderFocus = Color(0xFF6CB6F2);

  // States
  static const error = Color(0xFFFF6B7F);
  static const success = Color(0xFF55D693);
  static const warning = Color(0xFFFFB347);

  // Fondo degradado de las pantallas principales
  static const fondoArriba = Color(0xFF2A4259);
  static const fondoMedio = Color(0xFF0F1A2A);
  static const fondoAbajo = Color(0xFF09101A);

  // Texto del botón claro sobre fondo oscuro
  static const botonClaro = Color(0xFFE8F0F8);
  static const tintaBotonClaro = Color(0xFF0E1A2B);

  // Barra de navegación y botones oscuros sobre vidrio
  static const barra = Color(0xFF0E1826);
  static const botonOscuro = Color(0xFF0C1624);
}

abstract final class AppGradients {
  static const brand = LinearGradient(
    colors: [AppColors.gradientMid, AppColors.gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandVertical = LinearGradient(
    colors: [AppColors.gradientMid, AppColors.gradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const card = LinearGradient(
    colors: [Color(0xFF1C3A5E), Color(0xFF12253F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Fondo de las pantallas principales: azul acerado arriba que cae a casi negro.
  static const fondo = LinearGradient(
    colors: [AppColors.fondoArriba, AppColors.fondoMedio, AppColors.fondoAbajo],
    stops: [0.0, 0.42, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Fondo de Estadísticas: azul más vivo, que se aclara hacia abajo.
  static const fondoAzul = LinearGradient(
    colors: [Color(0xFF203A52), Color(0xFF1A3F66), Color(0xFF2C65A0)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Tarjeta de saldo y tarjeta Vera: azul profundo con un destello teal abajo a la derecha.
  static const tarjetaSaldo = LinearGradient(
    colors: [Color(0xFF3A6A94), Color(0xFF1F4A74), Color(0xFF2A7478)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Orbe del botón central de Vera.
  static const orbe = RadialGradient(
    colors: [Color(0xFF9BE3F2), Color(0xFF3F8FE0), Color(0xFF2456B8)],
    stops: [0.0, 0.55, 1.0],
    center: Alignment(-0.3, -0.4),
  );
}

abstract final class AppTheme {
  static ThemeData get dark => _tema(
    paleta: PaletaVera.oscura,
    esquema: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.gradientMid,
      onPrimary: AppColors.textPrimary,
      primaryContainer: Color(0xFF1B3A63),
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.background,
      secondaryContainer: Color(0xFF123350),
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    ),
  );

  /// Modo claro: mismos azules de marca, fondos y superficies claros.
  static ThemeData get light => _tema(
    paleta: PaletaVera.clara,
    esquema: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF214E8C),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD6E6F8),
      onPrimaryContainer: Color(0xFF0E1A2B),
      secondary: Color(0xFF1D5FB0),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE1ECF9),
      onSecondaryContainer: Color(0xFF0E1A2B),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0E1A2B),
      error: Color(0xFFC0283F),
      onError: Color(0xFFFFFFFF),
      outline: Color(0xFFD3DDEA),
      outlineVariant: Color(0xFFD3DDEA),
    ),
  );

  static ThemeData _tema({
    required PaletaVera paleta,
    required ColorScheme esquema,
  }) => ThemeData(
    useMaterial3: true,
    brightness: esquema.brightness,
    scaffoldBackgroundColor: paleta.background,
    colorScheme: esquema,
    extensions: [paleta],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: paleta.esClara
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: paleta.textPrimary),
    ),
    inputDecorationTheme: _campos(paleta),
    textTheme: _textos(paleta),
    dividerTheme: DividerThemeData(color: paleta.border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: paleta.surfaceVariant,
      contentTextStyle: TextStyle(color: paleta.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static InputDecorationTheme _campos(PaletaVera paleta) =>
      InputDecorationTheme(
        filled: true,
        fillColor: paleta.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: paleta.bordeCampo),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: paleta.bordeCampo),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: paleta.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: paleta.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: paleta.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: paleta.textMuted, fontSize: 15),
        prefixIconColor: paleta.textMuted,
        suffixIconColor: paleta.textMuted,
      );

  static TextTheme _textos(PaletaVera paleta) => TextTheme(
    displayLarge: TextStyle(
      color: paleta.textPrimary,
      fontSize: 42,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      color: paleta.textPrimary,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineLarge: TextStyle(
      color: paleta.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      color: paleta.textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleLarge: TextStyle(
      color: paleta.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      color: paleta.textSecondary,
      fontSize: 16,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: paleta.textSecondary,
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: TextStyle(color: paleta.textMuted, fontSize: 12),
  );
}
