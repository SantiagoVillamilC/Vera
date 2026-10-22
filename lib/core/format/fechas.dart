/// Convierte un instante a hora local. [offset] inyectable permite probar sin
/// depender de la zona del equipo. El resultado sirve tanto para la hora como
/// para agrupar por día (campos year, month, day, hour, minute).
DateTime aLocal(DateTime utc, {Duration? offset}) {
  if (offset == null) return utc.toLocal();
  return utc.toUtc().add(offset);
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Nombre del mes en minúscula: 1 es enero. Fuera de rango devuelve una cadena vacía.
String nombreDeMes(int mes) => mes >= 1 && mes <= 12 ? _meses[mes - 1] : '';

/// Mes calendario `YYYY-MM` de un instante, en la hora de Colombia (UTC-5, sin horario de verano),
/// que es la que usa `GET /v1/inteligencia/resumen`.
String mesDeBogota(DateTime instante) {
  final b = instante.toUtc().subtract(const Duration(hours: 5));
  return '${b.year}-${b.month.toString().padLeft(2, '0')}';
}

/// El mes calendario anterior a uno `YYYY-MM`.
String mesAnterior(String mes) {
  final a = int.parse(mes.substring(0, 4));
  final m = int.parse(mes.substring(5, 7));
  return m == 1 ? '${a - 1}-12' : '$a-${(m - 1).toString().padLeft(2, '0')}';
}
