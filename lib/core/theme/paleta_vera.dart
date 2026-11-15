import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Paleta de superficies, textos y acentos que cambia con el modo de la app.
///
/// La oscura se arma con las constantes de [AppColors], así que VeraDark queda
/// idéntico. La clara conserva los azules de marca y solo sube la luminosidad
/// de fondos y superficies, y oscurece los acentos que se usan como texto para
/// llegar a 4,5 a 1 sobre fondo claro.
@immutable
class PaletaVera extends ThemeExtension<PaletaVera> {
  const PaletaVera({
    required this.esClara,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderGlass,
    required this.borderFocus,
    required this.bordeCampo,
    required this.gradientStart,
    required this.accent,
    required this.accentGreen,
    required this.accentPink,
    required this.error,
    required this.success,
    required this.warning,
    required this.botonClaro,
    required this.tintaBotonClaro,
    required this.botonOscuro,
    required this.barra,
    required this.velo,
    required this.vidrio,
    required this.fondo,
    required this.fondoAzul,
  });

  /// Verdadero en el modo claro.
  final bool esClara;

  // Fondos y superficies
  final Color background;
  final Color surface;
  final Color surfaceVariant;

  // Texto
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Bordes
  final Color border;
  final Color borderGlass;
  final Color borderFocus;

  /// Borde de los campos de texto, con 3 a 1 de contraste contra su entorno.
  final Color bordeCampo;

  // Acentos y estados, ya ajustados para usarse como texto o icono
  final Color gradientStart;
  final Color accent;
  final Color accentGreen;
  final Color accentPink;
  final Color error;
  final Color success;
  final Color warning;

  // Botones y barra
  final Color botonClaro;
  final Color tintaBotonClaro;
  final Color botonOscuro;
  final Color barra;

  /// Base de los velos translúcidos: blanco en oscuro, tinta en claro.
  final Color velo;

  /// Relleno de las tarjetas de vidrio: velo blanco en oscuro, blanco casi opaco en claro.
  final Color vidrio;

  // Fondos degradados de las pantallas
  final Gradient fondo;
  final Gradient fondoAzul;

  static const oscura = PaletaVera(
    esClara: false,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceVariant: AppColors.surfaceVariant,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    borderGlass: AppColors.borderGlass,
    borderFocus: AppColors.borderFocus,
    bordeCampo: AppColors.border,
    gradientStart: AppColors.gradientStart,
    accent: AppColors.accent,
    accentGreen: AppColors.accentGreen,
    accentPink: AppColors.accentPink,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
    botonClaro: AppColors.botonClaro,
    tintaBotonClaro: AppColors.tintaBotonClaro,
    botonOscuro: AppColors.botonOscuro,
    barra: AppColors.barra,
    velo: Color(0xFFFFFFFF),
    vidrio: Color(0x0EFFFFFF),
    fondo: AppGradients.fondo,
    fondoAzul: AppGradients.fondoAzul,
  );

  static const clara = PaletaVera(
    esClara: true,
    background: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE9EFF7),
    textPrimary: Color(0xFF0E1A2B),
    textSecondary: Color(0xFF44546C),
    textMuted: Color(0xFF52627A),
    border: Color(0xFFD3DDEA),
    borderGlass: Color(0x240E1A2B),
    borderFocus: Color(0xFF1D5FB0),
    bordeCampo: Color(0xFF74839D),
    gradientStart: Color(0xFF1D5FB0),
    accent: Color(0xFF1D5FB0),
    accentGreen: Color(0xFF127040),
    accentPink: Color(0xFFB8365C),
    error: Color(0xFFC0283F),
    success: Color(0xFF127040),
    warning: Color(0xFF8F5200),
    botonClaro: Color(0xFF214E8C),
    tintaBotonClaro: Color(0xFFFFFFFF),
    botonOscuro: Color(0xFFFFFFFF),
    barra: Color(0xFFFFFFFF),
    velo: Color(0xFF0E1A2B),
    vidrio: Color(0xD6FFFFFF),
    fondo: LinearGradient(
      colors: [Color(0xFFE8F0FA), Color(0xFFF3F7FC), Color(0xFFF8FAFD)],
      stops: [0.0, 0.42, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    fondoAzul: LinearGradient(
      colors: [Color(0xFFDCE9F7), Color(0xFFE6EFFA), Color(0xFFF1F6FC)],
      stops: [0.0, 0.5, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Paleta del tema activo, o la oscura si el árbol no trae la extensión.
  static PaletaVera de(BuildContext context) =>
      Theme.of(context).extension<PaletaVera>() ?? oscura;

  // copyWith y lerp son marcadores de posicion: ThemeExtension los exige, pero
  // la app no tiene un interruptor de tema en tiempo de ejecucion (el modo se
  // fija por dart-define al compilar), asi que nunca se mezclan dos paletas ni
  // se copia una con cambios. Si algun dia hay interruptor, deben implementarse
  // campo por campo.
  @override
  PaletaVera copyWith() => this;

  // Salta de una paleta a la otra a la mitad de la transicion (t = 0,5).
  @override
  PaletaVera lerp(ThemeExtension<PaletaVera>? other, double t) {
    if (other is! PaletaVera) return this;
    return t < 0.5 ? this : other;
  }
}

/// Fuerza la paleta oscura en un tramo del árbol.
///
/// Las superficies de marca (tarjeta de saldo, tarjeta Vera, orbes) son de
/// gradiente azul en los dos modos, así que su contenido conserva los colores
/// de VeraDark aunque el resto de la pantalla sea clara.
class ZonaOscura extends StatelessWidget {
  const ZonaOscura({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.paleta.esClara) return child;
    return Theme(
      data: Theme.of(context).copyWith(extensions: const [PaletaVera.oscura]),
      child: child,
    );
  }
}

extension PaletaDeContexto on BuildContext {
  /// Paleta del modo activo. Sin extensión en el tema, devuelve la oscura.
  PaletaVera get paleta => PaletaVera.de(this);
}
