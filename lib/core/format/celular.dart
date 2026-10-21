import 'package:flutter/services.dart';

/// Largo del celular colombiano sin indicativo. El cliente antepone `+57` al
/// enviarlo (`AuthRepository.toE164`), que es el E.164 que valida el backend.
const longitudCelularColombiano = 10;

const _indicativo = '57';

/// Limita un campo de celular a lo que admite el contrato: solo dígitos y
/// como máximo [longitudCelularColombiano]. Un número pegado con el indicativo
/// (`+57 310 555 0404`) se queda con sus 10 dígitos. Sin este límite, un
/// 11.º dígito llegaba a `toE164`, que lo enviaba como `+6...` sin `+57`.
class CelularColombianoFormatter extends TextInputFormatter {
  const CelularColombianoFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == longitudCelularColombiano + _indicativo.length &&
        digitos.startsWith(_indicativo)) {
      digitos = digitos.substring(_indicativo.length);
    }
    if (digitos.length > longitudCelularColombiano) {
      digitos = digitos.substring(0, longitudCelularColombiano);
    }
    if (digitos == newValue.text) return newValue;
    return TextEditingValue(
      text: digitos,
      selection: TextSelection.collapsed(offset: digitos.length),
    );
  }
}
