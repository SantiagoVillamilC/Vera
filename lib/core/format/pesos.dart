final _cien = BigInt.from(100);

// Formato unico $12.345: los centavos se muestran (coma y dos digitos) solo si no son multiplo de 100.
String formatPesos(BigInt centavos) {
  final negativo = centavos.isNegative;
  final abs = centavos.abs();
  final enteros = (abs ~/ _cien).toString();
  final b = StringBuffer();
  for (var i = 0; i < enteros.length; i++) {
    if (i > 0 && (enteros.length - i) % 3 == 0) b.write('.');
    b.write(enteros[i]);
  }
  final cents = (abs % _cien).toInt();
  final fraccion = cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}';
  return '${negativo ? '-' : ''}\$$b$fraccion';
}

String formatPesosInt(int centavos) => formatPesos(BigInt.from(centavos));
