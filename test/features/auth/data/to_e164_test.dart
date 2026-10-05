import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

// El contrato (api/openapi.yaml de Backend_Vera) pide el celular en E.164. Los
// campos de celular de la app limitan la entrada a 10 dígitos, así que a
// toE164 solo le llegan esos 10 dígitos (o 12 si empiezan por 57, pegados).
void main() {
  group('AuthRepository.toE164', () {
    test('10 dígitos llevan +57', () {
      expect(AuthRepository.toE164('3105550404'), '+573105550404');
    });

    test('12 dígitos que empiezan por 57 ya traen el indicativo', () {
      expect(AuthRepository.toE164('573105550404'), '+573105550404');
    });

    test('ignora espacios, guiones y el +', () {
      expect(AuthRepository.toE164('+57 310-555 0404'), '+573105550404');
      expect(AuthRepository.toE164('310 555 0404'), '+573105550404');
    });

    test('un 11 dígitos sale sin +57: por eso los campos no lo admiten', () {
      expect(AuthRepository.toE164('63105550404'), '+63105550404');
    });
  });
}
