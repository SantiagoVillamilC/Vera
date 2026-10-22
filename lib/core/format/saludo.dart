/// "Buenos días", "Buenas tardes" o "Buenas noches" según la hora local.
String saludoDeLaHora(DateTime ahora) {
  final h = ahora.hour;
  if (h < 12) return 'Buenos días,';
  if (h < 19) return 'Buenas tardes,';
  return 'Buenas noches,';
}

/// Iniciales para el avatar: la primera letra de las dos primeras palabras del nombre.
String inicialesDe(String? nombre) {
  final palabras = (nombre ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .toList();
  if (palabras.isEmpty) return 'V';
  return palabras.map((p) => p[0].toUpperCase()).join();
}
