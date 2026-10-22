import 'package:flutter/material.dart';

/// Par fondo y tinta de los iconos y etiquetas de categoría de VeraDark.
class TinteVera {
  const TinteVera(this.fondo, this.tinta);

  final Color fondo;
  final Color tinta;

  static const naranja = TinteVera(Color(0xFF3A2418), Color(0xFFF59E5B));
  static const azul = TinteVera(Color(0xFF16304B), Color(0xFF6CB6F2));
  static const verde = TinteVera(Color(0xFF15301F), Color(0xFF55D693));
  static const teal = TinteVera(Color(0xFF12302D), Color(0xFF3ED6B0));
  static const rosa = TinteVera(Color(0xFF3A1A27), Color(0xFFF07A9C));
  static const morado = TinteVera(Color(0xFF271F4D), Color(0xFFA58BF2));
  static const ambar = TinteVera(Color(0xFF332A10), Color(0xFFE7B23E));
  static const gris = TinteVera(Color(0xFF1C2838), Color(0xFF9AA9BD));
}

String _sinTildes(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

/// Color de una categoría por su nombre visible. Las desconocidas quedan en gris.
TinteVera tinteDeCategoria(String nombre) {
  final n = _sinTildes(nombre);
  if (n.contains('restaurante') || n.contains('domicilio')) {
    return TinteVera.naranja;
  }
  if (n.contains('transporte')) return TinteVera.azul;
  if (n.contains('salario') || n.contains('ingreso')) return TinteVera.verde;
  if (n.contains('mercado') || n.contains('alimento')) return TinteVera.teal;
  if (n.contains('salud')) return TinteVera.rosa;
  if (n.contains('entretenimiento')) return TinteVera.morado;
  if (n.contains('vivienda') || n.contains('servicio')) return TinteVera.azul;
  if (n.contains('compra')) return TinteVera.azul;
  if (n.contains('educacion')) return TinteVera.morado;
  if (n.contains('comision') || n.contains('costo')) return TinteVera.ambar;
  return TinteVera.gris;
}

/// Icono de una categoría por su nombre visible.
IconData iconoDeCategoria(String nombre) {
  final n = _sinTildes(nombre);
  if (n.contains('restaurante') || n.contains('domicilio')) {
    return Icons.restaurant_rounded;
  }
  if (n.contains('transporte')) return Icons.directions_bus_outlined;
  if (n.contains('salario') || n.contains('ingreso')) {
    return Icons.work_outline_rounded;
  }
  if (n.contains('mercado') || n.contains('alimento')) {
    return Icons.shopping_cart_outlined;
  }
  if (n.contains('salud')) return Icons.favorite_border_rounded;
  if (n.contains('entretenimiento')) return Icons.play_circle_outline_rounded;
  if (n.contains('vivienda') || n.contains('servicio')) {
    return Icons.home_outlined;
  }
  if (n.contains('compra')) return Icons.shopping_bag_outlined;
  if (n.contains('educacion')) return Icons.school_outlined;
  if (n.contains('comision') || n.contains('costo')) {
    return Icons.receipt_long_outlined;
  }
  return Icons.sell_outlined;
}
