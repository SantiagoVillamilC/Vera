/// Los cinco tipos de llave de Bre-B y su forma, portados desde el backend
/// (`patronesDeLlave` en internal/nucleo/directorio.go). El celular de una
/// llave son 10 dígitos que empiezan por 3: no es E.164, no usar
/// normalizarDestino.
enum TipoLlaveBreB {
  documento('documento'),
  celular('celular'),
  correo('correo'),
  alfanumerico('alfanumerico'),
  comercio('comercio');

  const TipoLlaveBreB(this.codigo);

  /// Valor que viaja en `tipo_llave`.
  final String codigo;
}

final Map<TipoLlaveBreB, RegExp> patronesDeLlave = {
  TipoLlaveBreB.documento: RegExp(r'^[0-9]{6,10}$'),
  TipoLlaveBreB.celular: RegExp(r'^3[0-9]{9}$'),
  TipoLlaveBreB.correo:
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
  TipoLlaveBreB.alfanumerico: RegExp(r'^@[A-Za-z0-9]{1,64}$'),
  TipoLlaveBreB.comercio: RegExp(r'^[A-Za-z0-9]{6,20}$'),
};

/// Recorta el valor y lo valida con el patrón del tipo, sin ninguna otra
/// transformación. Devuelve null si no tiene la forma del tipo.
String? normalizarLlave(TipoLlaveBreB tipo, String raw) {
  final valor = raw.trim();
  final patron = patronesDeLlave[tipo];
  if (patron == null || !patron.hasMatch(valor)) return null;
  return valor;
}
