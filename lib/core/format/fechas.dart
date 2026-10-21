/// Convierte un instante a hora local. [offset] inyectable permite probar sin
/// depender de la zona del equipo. El resultado sirve tanto para la hora como
/// para agrupar por día (campos year, month, day, hour, minute).
DateTime aLocal(DateTime utc, {Duration? offset}) {
  if (offset == null) return utc.toLocal();
  return utc.toUtc().add(offset);
}
