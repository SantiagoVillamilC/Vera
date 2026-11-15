import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/core/theme/tintes.dart';

/// Relación de contraste de WCAG 2.x entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Texto normal: 4,5 a 1. Componentes de interfaz y gráficos: 3 a 1.
const _umbralTexto = 4.5;
const _umbralComponente = 3.0;

void main() {
  const p = PaletaVera.clara;
  final primerColorDelFondo = (p.fondo as LinearGradient).colors.first;
  final fondosDeTexto = <String, Color>{
    'fondo': p.background,
    'superficie': p.surface,
    'campo': p.surfaceVariant,
    'degradado de pantalla': primerColorDelFondo,
    'degradado de estadísticas': (p.fondoAzul as LinearGradient).colors.first,
  };

  group('PaletaVera.clara, texto normal sobre cada fondo', () {
    final textos = <String, Color>{
      'texto principal': p.textPrimary,
      'texto secundario': p.textSecondary,
      'texto tenue': p.textMuted,
      'acento': p.accent,
      'acento de enlaces': p.gradientStart,
      'verde de montos': p.accentGreen,
      'éxito': p.success,
      'rosa de gastos': p.accentPink,
      'error': p.error,
      'aviso': p.warning,
    };
    for (final texto in textos.entries) {
      for (final fondo in fondosDeTexto.entries) {
        test('${texto.key} sobre ${fondo.key}', () {
          expect(
            contraste(texto.value, fondo.value),
            greaterThanOrEqualTo(_umbralTexto),
          );
        });
      }
    }
  });

  group('PaletaVera.clara, botones', () {
    test('botón principal: tinta sobre fondo del botón', () {
      expect(
        contraste(p.tintaBotonClaro, p.botonClaro),
        greaterThanOrEqualTo(_umbralTexto),
      );
    });

    test('botón de gradiente de marca: blanco sobre ambos extremos', () {
      expect(
        contraste(Colors.white, AppColors.gradientMid),
        greaterThanOrEqualTo(_umbralTexto),
      );
      expect(
        contraste(Colors.white, AppColors.gradientEnd),
        greaterThanOrEqualTo(_umbralTexto),
      );
    });

    test('el botón principal se distingue del fondo (componente)', () {
      expect(
        contraste(p.botonClaro, p.background),
        greaterThanOrEqualTo(_umbralComponente),
      );
    });

    test('el texto principal se lee sobre el botón oscuro de iconos', () {
      expect(
        contraste(p.textPrimary, p.botonOscuro),
        greaterThanOrEqualTo(_umbralTexto),
      );
    });
  });

  group('PaletaVera.clara, componentes de interfaz', () {
    test('borde de los campos contra el fondo y contra su relleno', () {
      expect(
        contraste(p.bordeCampo, p.background),
        greaterThanOrEqualTo(_umbralComponente),
      );
      expect(
        contraste(p.bordeCampo, p.surfaceVariant),
        greaterThanOrEqualTo(_umbralComponente),
      );
    });

    test('borde de foco contra el relleno del campo', () {
      expect(
        contraste(p.borderFocus, p.surfaceVariant),
        greaterThanOrEqualTo(_umbralComponente),
      );
    });

    test('íconos de acento contra la superficie', () {
      for (final icono in [p.accent, p.accentGreen, p.error, p.warning]) {
        expect(
          contraste(icono, p.surface),
          greaterThanOrEqualTo(_umbralComponente),
        );
      }
    });
  });

  group('TinteVera en el modo claro', () {
    final todos = <String, TinteVera>{
      'naranja': TinteVera.naranja,
      'azul': TinteVera.azul,
      'verde': TinteVera.verde,
      'teal': TinteVera.teal,
      'rosa': TinteVera.rosa,
      'morado': TinteVera.morado,
      'ámbar': TinteVera.ambar,
      'gris': TinteVera.gris,
    };
    for (final e in todos.entries) {
      test('${e.key}: icono sobre su fondo pastel', () {
        final t = e.value.en(p);
        expect(t.fondo.computeLuminance(), greaterThan(0.5));
        expect(
          contraste(t.tinta, t.fondo),
          greaterThanOrEqualTo(_umbralComponente),
        );
      });
    }

    test('en oscuro devuelve el mismo tinte', () {
      expect(
        identical(TinteVera.azul.en(PaletaVera.oscura), TinteVera.azul),
        isTrue,
      );
    });
  });

  group('AppTheme', () {
    test('light es claro y dark sigue siendo oscuro', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.light.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.5),
      );
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.background);
    });

    test('cada tema trae su paleta', () {
      expect(AppTheme.light.extension<PaletaVera>()!.esClara, isTrue);
      expect(AppTheme.dark.extension<PaletaVera>()!.esClara, isFalse);
    });

    test('el texto del tema claro supera 4,5 a 1 sobre su fondo', () {
      final tema = AppTheme.light;
      final fondo = tema.scaffoldBackgroundColor;
      for (final estilo in [
        tema.textTheme.headlineLarge,
        tema.textTheme.bodyLarge,
        tema.textTheme.bodyMedium,
        tema.textTheme.bodySmall,
      ]) {
        expect(
          contraste(estilo!.color!, fondo),
          greaterThanOrEqualTo(_umbralTexto),
        );
      }
    });
  });

  testWidgets('sin extensión en el tema, la paleta es la oscura', (t) async {
    late PaletaVera visto;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            visto = context.paleta;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(visto, same(PaletaVera.oscura));
  });
}
