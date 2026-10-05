/// Pesos del módulo 11 de la DIAN, del dígito menos significativo al más.
const _pesosNit = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];

/// Comprueba el dígito de verificación DIAN (módulo 11) de un NIT.
///
/// Port línea por línea de validarNIT en Backend_Vera
/// (internal/platform/api/binding.go). Solo sirve para bloquear el envío con
/// un mensaje claro, el 422 por campo del backend sigue decidiendo.
bool esNitValido(String valor) {
  final nit = valor
      .trim()
      .replaceAll('.', '')
      .replaceAll('-', '')
      .replaceAll(' ', '');
  if (nit.length < 2 || nit.length > 15) return false;
  final cuerpo = nit.substring(0, nit.length - 1);
  final verif = nit.codeUnitAt(nit.length - 1);
  if (verif < 0x30 || verif > 0x39) return false;
  var suma = 0;
  for (var i = 0; i < cuerpo.length; i++) {
    final d = cuerpo.codeUnitAt(cuerpo.length - 1 - i);
    if (d < 0x30 || d > 0x39 || i >= _pesosNit.length) return false;
    suma += (d - 0x30) * _pesosNit[i];
  }
  var digito = suma % 11;
  if (digito > 1) digito = 11 - digito;
  return digito == verif - 0x30;
}
