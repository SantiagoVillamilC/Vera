/// Formateadores de moneda para COP.
/// F0: "1234500 se muestra como $12.345"
library;

/// Convierte centavos a pesos con separadores de miles.
/// 1234500 → "$12.345"
/// 0       → "$0"
String formatPesos(int centavos) {
  final pesos = centavos ~/ 100;
  final s = pesos.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$${b.toString()}';
}

/// Centavos a pesos con dos decimales (para el saldo principal).
/// 1234567 → "$ 12.345,67"
String formatPesosConCentavos(int centavos) {
  final pesos = centavos ~/ 100;
  final cents = (centavos.abs() % 100).toString().padLeft(2, '0');
  final s = pesos.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$ ${b.toString()},$cents';
}

/// Convierte texto de pesos (ingresado por el usuario) a centavos.
/// "12345" → 1234500  (el usuario escribe pesos, almacenamos centavos)
/// "0"     → 0
int parseCentavos(String pesosText) {
  final raw = pesosText.replaceAll(RegExp(r'[^\d]'), '');
  return (int.tryParse(raw) ?? 0) * 100;
}
