import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/biometric_session_store.dart';

import '../../support/biometria_fakes.dart';

void main() {
  late MemorySessionStore disco;
  late FakeKeyVault boveda;

  BiometricSessionStore abrirApp() =>
      BiometricSessionStore(base: disco, vault: boveda);

  setUp(() {
    disco = MemorySessionStore()
      ..access = 'acc-1'
      ..refresh = 'ref-1';
    boveda = FakeKeyVault();
  });

  test('habilitar cifra el refresh en disco y la sesión sigue usable', () async {
    final store = abrirApp();

    expect(await store.enable(), isTrue);

    expect(disco.refresh, startsWith(BiometricSessionStore.prefix));
    expect(disco.refresh, isNot(contains('ref-1')));
    expect(await store.readRefresh(), 'ref-1');
    expect(boveda.tieneClave, isTrue);
  });

  test('al reiniciar la app el refresh no se libera sin biometría', () async {
    await abrirApp().enable();

    final reinicio = abrirApp();

    expect(await reinicio.requiresUnlock(), isTrue);
    expect(await reinicio.readRefresh(), isNull);
  });

  test('biometría válida libera el refresh y la rotación se persiste', () async {
    await abrirApp().enable();
    final reinicio = abrirApp();

    expect(await reinicio.unlock(), isTrue);
    expect(await reinicio.readRefresh(), 'ref-1');

    await reinicio.saveTokens(access: 'acc-2', refresh: 'ref-2');
    expect(disco.refresh, startsWith(BiometricSessionStore.prefix));

    final otroReinicio = abrirApp();
    expect(await otroReinicio.unlock(), isTrue);
    expect(await otroReinicio.readRefresh(), 'ref-2');
  });

  test('biometría cancelada o fallida no libera el refresh', () async {
    await abrirApp().enable();
    boveda.aprobar = false;
    final reinicio = abrirApp();

    expect(await reinicio.unlock(), isFalse);
    expect(await reinicio.readRefresh(), isNull);
    expect(await reinicio.requiresUnlock(), isTrue);
  });

  test('lock vuelve a exigir biometría en el siguiente uso', () async {
    final store = abrirApp();
    await store.enable();

    store.lock();

    expect(await store.readRefresh(), isNull);
  });

  test('cancelar al habilitar no cambia nada', () async {
    boveda.aprobar = false;
    final store = abrirApp();

    expect(await store.enable(), isFalse);

    expect(disco.refresh, 'ref-1');
    expect(await store.isEnrolled(), isFalse);
    expect(boveda.tieneClave, isFalse);
  });

  test('un dispositivo distinto no hereda el desbloqueo', () async {
    await abrirApp().enable();
    final discoCopiado = MemorySessionStore()
      ..access = disco.access
      ..refresh = disco.refresh;
    final otraBoveda = FakeKeyVault();

    final otroDispositivo =
        BiometricSessionStore(base: discoCopiado, vault: otraBoveda);

    expect(await otroDispositivo.unlock(), isFalse);
    expect(await otroDispositivo.readRefresh(), isNull);
  });

  test('clear borra el enrolamiento y la clave', () async {
    final store = abrirApp();
    await store.enable();

    await store.clear();

    expect(boveda.tieneClave, isFalse);
    expect(disco.refresh, isNull);
    expect(await abrirApp().requiresUnlock(), isFalse);
  });

  test('sin biometría en el dispositivo no está disponible', () async {
    boveda.disponible = false;

    expect(await abrirApp().isAvailable(), isFalse);
  });

  test('sin enrolar el refresh se guarda como siempre', () async {
    final store = abrirApp();

    await store.saveTokens(access: 'a', refresh: 'r');

    expect(disco.refresh, 'r');
    expect(await store.requiresUnlock(), isFalse);
  });
}
