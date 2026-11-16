/// Tope de caracteres que acepta `/v1/vera/sintetizar` por petición (`maxLength` del contrato).
const maxCaracteresBackend = 400;

/// Tamaño objetivo de cada trozo. Queda por debajo del tope del backend porque la síntesis de 400
/// caracteres ronda los 14 s estimados y el plazo del cliente es de unos 11 s. Un trozo más corto
/// también baja la espera hasta que empieza a sonar.
const maxCaracteresPorTrozo = 240;

final _separador = RegExp(r'(?<=[.!?…])\s+|\s*\n+\s*');
final _espacios = RegExp(r'\s+');

/// Parte [texto] en trozos de hasta [maxCaracteres] caracteres para sintetizarlos por separado.
///
/// Corta en el final de una frase (`.`, `!`, `?`, `…` seguidos de espacio, o un salto de línea), así
/// que un decimal como `3.5` o un monto como `1.250.000` nunca se parte. Une frases enteras mientras
/// quepan. Una frase más larga que el tope se parte en límites de palabra. Solo una palabra sin
/// espacios más larga que el tope se corta a la fuerza, y en la práctica no ocurre. La longitud se
/// mide en unidades UTF-16, que nunca es menor que la cuenta de caracteres del backend.
List<String> partirEnTrozos(
  String texto, {
  int maxCaracteres = maxCaracteresPorTrozo,
}) {
  assert(maxCaracteres > 0 && maxCaracteres <= maxCaracteresBackend);
  final frases = <String>[];
  for (final frase in texto.trim().split(_separador)) {
    final limpia = frase.replaceAll(_espacios, ' ').trim();
    if (limpia.isEmpty) continue;
    frases.addAll(_partirFraseLarga(limpia, maxCaracteres));
  }

  final trozos = <String>[];
  var actual = '';
  for (final frase in frases) {
    if (actual.isEmpty) {
      actual = frase;
    } else if (actual.length + 1 + frase.length <= maxCaracteres) {
      actual = '$actual $frase';
    } else {
      trozos.add(actual);
      actual = frase;
    }
  }
  if (actual.isNotEmpty) trozos.add(actual);
  return trozos;
}

List<String> _partirFraseLarga(String frase, int max) {
  if (frase.length <= max) return [frase];
  final partes = <String>[];
  var resto = frase;
  while (resto.length > max) {
    var corte = resto.lastIndexOf(' ', max);
    if (corte <= 0) corte = max;
    partes.add(resto.substring(0, corte).trim());
    resto = resto.substring(corte).trim();
  }
  if (resto.isNotEmpty) partes.add(resto);
  return partes;
}
