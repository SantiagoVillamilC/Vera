import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/platform/url_opener.dart';

void main() {
  group('urlPagoSegura', () {
    test('admite https', () {
      expect(
        urlPagoSegura('https://pse.test/pagar?ref=1'),
        Uri.parse('https://pse.test/pagar?ref=1'),
      );
    });

    test('admite http', () {
      expect(urlPagoSegura('http://pse.test/pagar'), isNotNull);
    });

    test('rechaza javascript, otros esquemas y vacío', () {
      expect(urlPagoSegura('javascript:alert(1)'), isNull);
      expect(urlPagoSegura('intent://pagar#Intent;end'), isNull);
      expect(urlPagoSegura('file:///etc/passwd'), isNull);
      expect(urlPagoSegura('pse.test/pagar'), isNull);
      expect(urlPagoSegura(''), isNull);
    });

    test('rechaza una URL mal formada', () {
      expect(urlPagoSegura('http://['), isNull);
    });

    test('rechaza http sin host', () {
      expect(urlPagoSegura('https://'), isNull);
    });
  });

  test('UrlOpener es inyectable con un fake', () async {
    final fake = _FakeOpener();
    final UrlOpener opener = fake;
    expect(await opener.abrir(Uri.parse('https://a.test')), isTrue);
    expect(fake.abiertas, [Uri.parse('https://a.test')]);
  });
}

class _FakeOpener implements UrlOpener {
  final abiertas = <Uri>[];

  @override
  Future<bool> abrir(Uri uri) async {
    abiertas.add(uri);
    return true;
  }
}
