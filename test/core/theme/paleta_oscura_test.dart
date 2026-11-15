import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/paleta_vera.dart';

void main() {
  test('PaletaVera.oscura es identica a los valores de AppColors', () {
    const p = PaletaVera.oscura;
    expect(p.esClara, isFalse);
    expect(p.background, AppColors.background);
    expect(p.surface, AppColors.surface);
    expect(p.surfaceVariant, AppColors.surfaceVariant);
    expect(p.textPrimary, AppColors.textPrimary);
    expect(p.textSecondary, AppColors.textSecondary);
    expect(p.textMuted, AppColors.textMuted);
    expect(p.border, AppColors.border);
    expect(p.borderGlass, AppColors.borderGlass);
    expect(p.borderFocus, AppColors.borderFocus);
    expect(p.bordeCampo, AppColors.border);
    expect(p.gradientStart, AppColors.gradientStart);
    expect(p.accent, AppColors.accent);
    expect(p.accentGreen, AppColors.accentGreen);
    expect(p.accentPink, AppColors.accentPink);
    expect(p.error, AppColors.error);
    expect(p.success, AppColors.success);
    expect(p.warning, AppColors.warning);
    expect(p.botonClaro, AppColors.botonClaro);
    expect(p.tintaBotonClaro, AppColors.tintaBotonClaro);
    expect(p.botonOscuro, AppColors.botonOscuro);
    expect(p.barra, AppColors.barra);
    expect(p.fondo, AppGradients.fondo);
    expect(p.fondoAzul, AppGradients.fondoAzul);
  });

  test('los velos de la paleta oscura son blancos, como los literales previos', () {
    const p = PaletaVera.oscura;
    expect(p.velo, const Color(0xFFFFFFFF));
    expect(p.vidrio, const Color(0x0EFFFFFF));
  });
}
