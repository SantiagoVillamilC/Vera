import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/features/home/presentation/enviar_llave_screen.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/llave_bre_b.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

const _exito = 'Enviado. Verás el resultado en tu historial.';

typedef _Llamada = ({String tipo, String llave, String monto, String key});

class _FakeRepo implements NucleoRepository {
  Future<EnvioPorLlave> Function(_Llamada llamada) onEnviar = (l) async =>
      _envio(EstadoTransferencia.confirmada);

  final llamadas = <_Llamada>[];

  @override
  Future<EnvioPorLlave> transferirInterbancaria({
    required String tipoLlave,
    required String llave,
    required String monto,
    required String idempotencyKey,
  }) {
    final l = (
      tipo: tipoLlave,
      llave: llave,
      monto: monto,
      key: idempotencyKey,
    );
    llamadas.add(l);
    return onEnviar(l);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EnvioPorLlave _envio(EstadoTransferencia estado) => EnvioPorLlave(
  id: 'e1',
  tipoLlave: 'celular',
  llave: '3001234567',
  montoCentavos: BigInt.from(1000000),
  moneda: 'COP',
  estado: estado,
  creadaEn: DateTime.utc(2026),
  actualizadaEn: DateTime.utc(2026),
);

ApiException _api(String code, int status) =>
    ApiException(code: code, message: 'x', statusCode: status);

class _Entorno {
  final repo = _FakeRepo();
  final intent = IdempotencyIntent();
}

Future<_Entorno> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = _Entorno();
  await tester.pumpWidget(
    MaterialApp(
      home: EnviarLlaveScreen(repository: e.repo, intent: e.intent),
    ),
  );
  await tester.pump();
  return e;
}

Future<void> _elegirTipo(WidgetTester tester, TipoLlaveBreB tipo) async {
  await tester.tap(find.byKey(Key('tipo-${tipo.codigo}')));
  await tester.pump();
}

Future<void> _llenar(
  WidgetTester tester, {
  required String llave,
  String pesos = '10000',
}) async {
  await tester.enterText(find.byKey(const Key('llave')), llave);
  await tester.enterText(find.byKey(const Key('monto')), pesos);
  await tester.pump();
}

bool _botonHabilitado(WidgetTester tester) =>
    tester.widget<GradientButton>(find.byKey(const Key('enviar'))).onPressed !=
    null;

Future<void> _enviar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('enviar')));
  await tester.pump();
  await tester.pump();
}

bool _hayEntregado(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => (t.data ?? '').toLowerCase().contains('entregado'));

const _validos = <TipoLlaveBreB, List<String>>{
  TipoLlaveBreB.documento: ['123456', '1234567890', '  98765432  '],
  TipoLlaveBreB.celular: ['3001234567', '3999999999'],
  TipoLlaveBreB.correo: ['ana@correo.co', 'a.b+c@sub.dominio.com'],
  TipoLlaveBreB.alfanumerico: ['@ana', '@Ana123'],
  TipoLlaveBreB.comercio: ['ABC123', 'Tienda20Abcdefghijk'],
};

const _invalidos = <TipoLlaveBreB, List<String>>{
  TipoLlaveBreB.documento: ['12345', '12345678901', '12a456'],
  TipoLlaveBreB.celular: ['2001234567', '300123456', '30012345678'],
  TipoLlaveBreB.correo: ['ana', 'ana@correo', '@correo.co'],
  TipoLlaveBreB.alfanumerico: ['ana', '@', '@ana_1', '@ana lopez'],
  TipoLlaveBreB.comercio: ['ABC12', 'ABC 123', 'ABCDEFGHIJKLMNOPQRSTU'],
};

void main() {
  group('validación por patrón de cada tipo', () {
    for (final tipo in TipoLlaveBreB.values) {
      testWidgets('${tipo.codigo}: acepta las llaves válidas', (tester) async {
        await _pump(tester);
        await _elegirTipo(tester, tipo);
        for (final llave in _validos[tipo]!) {
          await _llenar(tester, llave: llave);
          expect(_botonHabilitado(tester), isTrue, reason: '"$llave"');
          expect(find.byKey(const Key('llave-error')), findsNothing);
        }
      });

      testWidgets('${tipo.codigo}: rechaza las llaves inválidas', (
        tester,
      ) async {
        await _pump(tester);
        await _elegirTipo(tester, tipo);
        for (final llave in _invalidos[tipo]!) {
          await _llenar(tester, llave: llave);
          expect(_botonHabilitado(tester), isFalse, reason: '"$llave"');
          expect(find.byKey(const Key('llave-error')), findsOneWidget);
        }
      });
    }

    testWidgets('una llave válida de otro tipo no vale al cambiar de tipo', (
      tester,
    ) async {
      await _pump(tester);
      await _llenar(tester, llave: '3001234567');
      await _elegirTipo(tester, TipoLlaveBreB.correo);
      expect(_botonHabilitado(tester), isFalse);
    });

    testWidgets('sin monto o con monto cero el botón no se habilita', (
      tester,
    ) async {
      await _pump(tester);
      await _elegirTipo(tester, TipoLlaveBreB.celular);
      await _llenar(tester, llave: '3001234567', pesos: '');
      expect(_botonHabilitado(tester), isFalse);
      await _llenar(tester, llave: '3001234567', pesos: '0');
      expect(_botonHabilitado(tester), isFalse);
    });
  });

  group('celular de 10 dígitos', () {
    testWidgets('no acepta el prefijo +57 ni 57 ni formato E.164', (
      tester,
    ) async {
      await _pump(tester);
      await _elegirTipo(tester, TipoLlaveBreB.celular);
      for (final llave in ['+573001234567', '573001234567', '+57 3001234567']) {
        await _llenar(tester, llave: llave);
        expect(_botonHabilitado(tester), isFalse, reason: llave);
      }
    });

    testWidgets('envía los 10 dígitos recortados y el monto a centavos', (
      tester,
    ) async {
      final e = await _pump(tester);
      await _elegirTipo(tester, TipoLlaveBreB.celular);
      await _llenar(tester, llave: '  3001234567 ', pesos: '10000');
      await _enviar(tester);

      expect(e.repo.llamadas, hasLength(1));
      expect(e.repo.llamadas.single.tipo, 'celular');
      expect(e.repo.llamadas.single.llave, '3001234567');
      expect(e.repo.llamadas.single.monto, '1000000');
    });

    testWidgets('el monto grande no pierde precisión', (tester) async {
      final e = await _pump(tester);
      await _elegirTipo(tester, TipoLlaveBreB.celular);
      await _llenar(tester, llave: '3001234567', pesos: '90071992547409931');
      await _enviar(tester);
      expect(e.repo.llamadas.single.monto, '9007199254740993100');
    });
  });

  group('resultado 2xx', () {
    testWidgets('muestra exactamente el mensaje de éxito y no dice entregado', (
      tester,
    ) async {
      await _pump(tester);
      await _elegirTipo(tester, TipoLlaveBreB.celular);
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);

      expect(find.text(_exito), findsOneWidget);
      expect(_hayEntregado(tester), isFalse);
    });

    for (final estado in [
      EstadoTransferencia.creada,
      EstadoTransferencia.reservada,
      EstadoTransferencia.despachada,
      EstadoTransferencia.confirmada,
    ]) {
      testWidgets('estado ${estado.name} muestra el mensaje exacto', (
        tester,
      ) async {
        final e = await _pump(tester);
        e.repo.onEnviar = (_) async => _envio(estado);
        await _llenar(tester, llave: '3001234567');
        await _enviar(tester);

        expect(find.text(_exito), findsOneWidget);
        expect(_hayEntregado(tester), isFalse);
      });
    }

    for (final estado in [
      EstadoTransferencia.fallida,
      EstadoTransferencia.compensada,
      EstadoTransferencia.indeterminada,
      EstadoTransferencia.desconocido,
    ]) {
      testWidgets(
        'estado ${estado.name} no va en verde y remite al historial',
        (tester) async {
          final e = await _pump(tester);
          e.repo.onEnviar = (_) async => _envio(estado);
          await _llenar(tester, llave: '3001234567');
          await _enviar(tester);

          expect(find.byKey(const Key('icono_exito')), findsNothing);
          final mensaje = tester
              .widget<Text>(find.byKey(const Key('resultado_mensaje')))
              .data!;
          expect(mensaje, contains('historial'));
          final estadoTexto = tester.widget<Text>(
            find.byKey(const Key('resultado_estado')),
          );
          expect(estadoTexto.style?.color, isNot(AppColors.accentGreen));
          expect(_hayEntregado(tester), isFalse);
        },
      );
    }

    testWidgets(
      'el éxito confirmado lleva marca de éxito, estado Exitoso y detalle',
      (tester) async {
        await _pump(tester);
        await _llenar(tester, llave: '3001234567');
        await _enviar(tester);
        await tester.pumpAndSettle();

        expect(find.text('¡Listo! Ya va en camino'), findsOneWidget);
        expect(find.byKey(const Key('icono_exito')), findsOneWidget);
        final estadoTexto = tester.widget<Text>(
          find.byKey(const Key('resultado_estado')),
        );
        expect(estadoTexto.data, 'Exitoso');
        expect(estadoTexto.style?.color, AppColors.accentGreen);
        expect(find.text('3001234567'), findsOneWidget);
        expect(find.text('Celular'), findsOneWidget);
        expect(find.text('Referencia'), findsOneWidget);
      },
    );

    testWidgets('tras el éxito se renueva la clave de idempotencia', (
      tester,
    ) async {
      final e = await _pump(tester);
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);

      final primera = e.repo.llamadas.single.key;
      final siguiente = e.intent.keyFor(
        destino: 'celular:3001234567',
        monto: BigInt.from(1000000),
      );
      expect(siguiente, isNot(primera));
    });
  });

  group('doble toque', () {
    testWidgets('dos toques con un envío en vuelo hacen una sola llamada', (
      tester,
    ) async {
      final completer = Completer<EnvioPorLlave>();
      final e = await _pump(tester);
      e.repo.onEnviar = (_) => completer.future;
      await _llenar(tester, llave: '3001234567');
      await tester.tap(find.byKey(const Key('enviar')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('enviar')), warnIfMissed: false);
      await tester.pump();

      expect(e.repo.llamadas, hasLength(1));
      completer.complete(_envio(EstadoTransferencia.confirmada));
      await tester.pump();
      await tester.pump();
      expect(e.repo.llamadas, hasLength(1));
      expect(find.text(_exito), findsOneWidget);
    });
  });

  group('clave de idempotencia', () {
    testWidgets('el 503 DirectoryUnavailable reutiliza la clave al reintentar', (
      tester,
    ) async {
      final e = await _pump(tester);
      var falla = true;
      e.repo.onEnviar = (_) async {
        if (falla) throw _api('DirectoryUnavailable', 503);
        return _envio(EstadoTransferencia.confirmada);
      };
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);
      expect(
        find.text(
          'El directorio de destinatarios no está disponible. Intenta más tarde.',
        ),
        findsOneWidget,
      );

      falla = false;
      await tester.tap(find.byKey(const Key('reintentar')));
      await tester.pump();
      await tester.pump();

      expect(e.repo.llamadas, hasLength(2));
      expect(e.repo.llamadas[1].key, e.repo.llamadas[0].key);
      expect(find.text(_exito), findsOneWidget);
    });

    testWidgets('el timeout deja el botón habilitado y reutiliza la clave', (
      tester,
    ) async {
      final e = await _pump(tester);
      var falla = true;
      e.repo.onEnviar = (_) async {
        if (falla) throw TimeoutException('x');
        return _envio(EstadoTransferencia.confirmada);
      };
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);

      expect(find.text('Error de conexión. Intenta de nuevo.'), findsOneWidget);
      expect(_botonHabilitado(tester), isTrue);

      falla = false;
      await _enviar(tester);
      expect(e.repo.llamadas, hasLength(2));
      expect(e.repo.llamadas[1].key, e.repo.llamadas[0].key);
    });

    testWidgets('el 422 renueva la clave', (tester) async {
      final e = await _pump(tester);
      e.repo.onEnviar = (_) async => throw _api('InsufficientFunds', 422);
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);
      await _enviar(tester);

      expect(e.repo.llamadas, hasLength(2));
      expect(e.repo.llamadas[1].key, isNot(e.repo.llamadas[0].key));
    });

    testWidgets('cambiar el monto genera una clave nueva', (tester) async {
      final e = await _pump(tester);
      e.repo.onEnviar = (_) async => throw TimeoutException('x');
      await _llenar(tester, llave: '3001234567', pesos: '10000');
      await _enviar(tester);
      await _llenar(tester, llave: '3001234567', pesos: '20000');
      await _enviar(tester);

      expect(e.repo.llamadas[1].key, isNot(e.repo.llamadas[0].key));
    });
  });

  group('mensajes por código', () {
    final casos = <(String, int, String)>[
      (
        'NotFound',
        404,
        'No encontramos esa llave. Revisa el dato e intenta de nuevo.',
      ),
      (
        'RecipientNotFound',
        404,
        'No encontramos esa llave. Revisa el dato e intenta de nuevo.',
      ),
      (
        'DirectoryUnavailable',
        503,
        'El directorio de destinatarios no está disponible. Intenta más tarde.',
      ),
      (
        'InsufficientFunds',
        422,
        'No tienes saldo suficiente para esta operación.',
      ),
      (
        'OperationLimitExceeded',
        422,
        'El monto supera el límite permitido por operación.',
      ),
      (
        'MonthlyQuotaExceeded',
        422,
        'Superaste tu límite mensual de operaciones.',
      ),
    ];
    for (final (codigo, status, mensaje) in casos) {
      testWidgets('$codigo muestra su mensaje', (tester) async {
        final e = await _pump(tester);
        e.repo.onEnviar = (_) async => throw _api(codigo, status);
        await _llenar(tester, llave: '3001234567');
        await _enviar(tester);

        expect(find.text(mensaje), findsOneWidget);
        expect(find.text(_exito), findsNothing);
        expect(_botonHabilitado(tester), isTrue);
      });
    }

    testWidgets('el reintentar solo aparece con errores 5xx', (tester) async {
      final e = await _pump(tester);
      e.repo.onEnviar = (_) async => throw _api('InsufficientFunds', 422);
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);
      expect(find.byKey(const Key('reintentar')), findsNothing);
    });

    testWidgets('un error de validación del servidor se muestra en español', (
      tester,
    ) async {
      final e = await _pump(tester);
      e.repo.onEnviar = (_) async => throw const ApiException(
        code: 'ValidationError',
        message: 'x',
        statusCode: 422,
        details: [
          {'field': 'llave', 'rule': 'required'},
        ],
      );
      await _llenar(tester, llave: '3001234567');
      await _enviar(tester);
      expect(find.text('La llave es obligatoria'), findsOneWidget);
    });
  });

  group('textos', () {
    testWidgets('ningún texto afirma que no hay comisión ni usa rayas', (
      tester,
    ) async {
      final e = await _pump(tester);
      e.repo.onEnviar = (_) async => throw _api('InsufficientFunds', 422);
      await _llenar(tester, llave: 'ana');
      final raya = String.fromCharCode(0x2014);
      final cortaRaya = String.fromCharCode(0x2013);
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .toList();
      for (final t in textos) {
        expect(t.contains('sin comisión'), isFalse);
        expect(t.contains('sin comision'), isFalse);
        expect(t.contains(raya), isFalse);
        expect(t.contains(cortaRaya), isFalse);
        expect(t.contains(';'), isFalse);
      }
    });
  });
}
