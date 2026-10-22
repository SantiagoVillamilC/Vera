import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/security/verificador_local.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/accion_card.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _fallo(int status, String code) => _json({
  'success': false,
  'data': null,
  'error': {'code': code, 'message': 'x'},
  'meta': null,
}, status);

Map<String, Object?> _accionJson(String estado, {bool codigo = false}) => {
  'id': 'a1',
  'estado': estado,
  'tipo': 'transferencia_interna',
  'destinatario': {'nombre': 'Laura R.', 'celular_parcial': '******4321'},
  'monto': '15000000',
  'moneda': 'COP',
  'requiere_codigo': codigo,
  'expira_en': DateTime.now()
      .add(const Duration(minutes: 5))
      .toUtc()
      .toIso8601String(),
};

http.Response _confirmada() => _json({
  'success': true,
  'data': {
    'accion_pendiente': _accionJson('confirmada'),
    'transferencia': {
      'id': 'tr-123',
      'destino': 'Laura R.',
      'monto': '15000000',
      'moneda': 'COP',
      'estado': 'confirmada',
      'creada_en': '2026-10-15T14:17:00-05:00',
      'actualizada_en': '2026-10-15T14:17:01-05:00',
    },
  },
  'error': null,
  'meta': null,
}, 200);

http.Response _desafio() => _json({
  'success': true,
  'data': {'challenge_id': 'des-1', 'expira_en_segundos': 300},
  'error': null,
  'meta': null,
}, 200);

class _VerificadorFalso implements VerificadorLocal {
  _VerificadorFalso(this.resultado);
  ResultadoVerificacion resultado;
  int llamadas = 0;

  @override
  Future<ResultadoVerificacion> verificar(String motivo) async {
    llamadas++;
    return resultado;
  }
}

class _Anfitrion extends StatefulWidget {
  const _Anfitrion({
    required this.inicial,
    required this.repo,
    required this.verificador,
  });
  final AccionPendiente inicial;
  final AsistenteRepository repo;
  final VerificadorLocal verificador;

  @override
  State<_Anfitrion> createState() => _AnfitrionState();
}

class _AnfitrionState extends State<_Anfitrion> {
  late AccionPendiente accion = widget.inicial;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: AccionCard(
        key: ValueKey(accion.id),
        accion: accion,
        repo: widget.repo,
        verificador: widget.verificador,
        onActualizada: (a) => setState(() => accion = a),
      ),
    ),
  );
}

class _Montaje {
  _Montaje(this.vistos, this.verificador);
  final List<http.Request> vistos;
  final _VerificadorFalso verificador;

  Iterable<http.Request> al(String sufijo) =>
      vistos.where((r) => r.url.path.endsWith(sufijo));

  Map<String, dynamic> cuerpo(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;
}

Future<_Montaje> _montar(
  WidgetTester t, {
  required http.Response Function(http.Request) responder,
  ResultadoVerificacion verificacion = ResultadoVerificacion.exitosa,
  bool requiereCodigo = false,
}) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
    vistos.add(r);
    return responder(r);
  });
  final verificador = _VerificadorFalso(verificacion);
  await t.pumpWidget(
    MaterialApp(
      home: _Anfitrion(
        inicial: AccionPendiente.fromJson(
          _accionJson('pendiente', codigo: requiereCodigo),
        ),
        repo: AsistenteRepository(
          client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
        ),
        verificador: verificador,
      ),
    ),
  );
  await t.pump();
  return _Montaje(vistos, verificador);
}

Future<void> _asentar(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _escribirCodigo(WidgetTester t, String codigo) async {
  for (final d in codigo.split('')) {
    await t.tap(find.text(d).last);
    await t.pump();
  }
  await _asentar(t);
}

void main() {
  testWidgets('muestra monto, moneda, destinatario y tiempo restante', (
    t,
  ) async {
    await _montar(t, responder: (_) => _confirmada());

    expect(find.text('\$150.000'), findsOneWidget);
    expect(find.text('COP'), findsOneWidget);
    expect(find.textContaining('Laura R.'), findsOneWidget);
    expect(find.textContaining('******4321'), findsOneWidget);
    expect(find.textContaining('Vence en'), findsOneWidget);
  });

  group('sin código requerido', () {
    testWidgets(
      'con verificación local exitosa confirma y muestra el resultado',
      (t) async {
        final m = await _montar(t, responder: (_) => _confirmada());

        await t.tap(find.text('Confirmar'));
        await _asentar(t);

        expect(m.verificador.llamadas, 1);
        final post = m.al('/confirmar').single;
        expect(m.cuerpo(post), isEmpty);
        expect(find.text('Transferencia enviada.'), findsOneWidget);
        expect(find.text('Identificador: tr-123'), findsOneWidget);
        expect(find.textContaining('15/10/2026'), findsOneWidget);
        expect(find.text('Confirmar'), findsNothing);
      },
    );

    testWidgets('si la verificación se rechaza no llama al servidor', (
      t,
    ) async {
      final m = await _montar(
        t,
        responder: (_) => _confirmada(),
        verificacion: ResultadoVerificacion.rechazada,
      );

      await t.tap(find.text('Confirmar'));
      await _asentar(t);

      expect(m.vistos, isEmpty);
      expect(
        find.textContaining('No pudimos verificar que eres tú'),
        findsOneWidget,
      );
      expect(find.text('Confirmar'), findsOneWidget);
    });

    testWidgets(
      'sin biometría ni bloqueo usa el código y avisa sin_verificacion_local',
      (t) async {
        final m = await _montar(
          t,
          verificacion: ResultadoVerificacion.noDisponible,
          responder: (r) =>
              r.url.path.endsWith('/codigo') ? _desafio() : _confirmada(),
        );

        await t.tap(find.text('Confirmar'));
        await _asentar(t);
        expect(m.al('/codigo'), hasLength(1));
        expect(find.text('Código de confirmación'), findsOneWidget);

        await _escribirCodigo(t, '123456');

        final cuerpo = m.cuerpo(m.al('/confirmar').single);
        expect(cuerpo['codigo'], '123456');
        expect(cuerpo['desafio_id'], 'des-1');
        expect(cuerpo['sin_verificacion_local'], true);
        expect(find.text('Transferencia enviada.'), findsOneWidget);
      },
    );

    testWidgets('si el servidor pide el código tras la verificación, lo pide', (
      t,
    ) async {
      var confirmaciones = 0;
      final m = await _montar(
        t,
        responder: (r) {
          if (r.url.path.endsWith('/codigo')) return _desafio();
          confirmaciones++;
          return confirmaciones == 1
              ? _fallo(403, 'SecondFactorRequired')
              : _confirmada();
        },
      );

      await t.tap(find.text('Confirmar'));
      await _asentar(t);
      expect(find.text('Código de confirmación'), findsOneWidget);

      await _escribirCodigo(t, '654321');

      expect(m.cuerpo(m.al('/confirmar').last)['codigo'], '654321');
      expect(find.text('Transferencia enviada.'), findsOneWidget);
    });
  });

  group('con código requerido', () {
    testWidgets(
      'solicita el código, tiene reenvío tras 60 segundos y confirma',
      (t) async {
        final m = await _montar(
          t,
          requiereCodigo: true,
          responder: (r) =>
              r.url.path.endsWith('/codigo') ? _desafio() : _confirmada(),
        );

        await t.tap(find.text('Confirmar con código'));
        await _asentar(t);
        expect(m.verificador.llamadas, 0);
        expect(find.text('Reenviar código en 60s'), findsOneWidget);
        expect(find.byKey(const Key('reenviar_codigo')), findsNothing);

        await t.pump(const Duration(seconds: 60));
        expect(find.byKey(const Key('reenviar_codigo')), findsOneWidget);

        await t.tap(find.byKey(const Key('reenviar_codigo')));
        await _asentar(t);
        expect(m.al('/codigo'), hasLength(2));
        expect(find.text('Reenviar código en 60s'), findsOneWidget);

        await _escribirCodigo(t, '111222');
        final cuerpo = m.cuerpo(m.al('/confirmar').single);
        expect(cuerpo['codigo'], '111222');
        expect(cuerpo.containsKey('sin_verificacion_local'), isFalse);
      },
    );

    testWidgets('un código incorrecto muestra el mensaje y deja reintentar', (
      t,
    ) async {
      var intentos = 0;
      await _montar(
        t,
        requiereCodigo: true,
        responder: (r) {
          if (r.url.path.endsWith('/codigo')) return _desafio();
          intentos++;
          return intentos == 1 ? _fallo(400, 'OtpInvalid') : _confirmada();
        },
      );

      await t.tap(find.text('Confirmar con código'));
      await _asentar(t);
      await _escribirCodigo(t, '000000');

      expect(
        find.text('El código no es correcto. Revísalo e intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Código de confirmación'), findsOneWidget);

      await _escribirCodigo(t, '123456');
      expect(find.text('Transferencia enviada.'), findsOneWidget);
    });

    testWidgets(
      'si agota los intentos cierra, informa y la acción sigue sin confirmar',
      (t) async {
        await _montar(
          t,
          requiereCodigo: true,
          responder: (r) => r.url.path.endsWith('/codigo')
              ? _desafio()
              : _fallo(429, 'OtpTooManyAttempts'),
        );

        await t.tap(find.text('Confirmar con código'));
        await _asentar(t);
        await _escribirCodigo(t, '000000');
        await t.pump(const Duration(milliseconds: 400));

        expect(find.text('Código de confirmación'), findsNothing);
        expect(
          find.text(
            'Superaste el límite de intentos del código. Solicita uno nuevo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Confirmar con código'), findsOneWidget);
      },
    );
  });

  group('estados finales', () {
    testWidgets('cancelar llama al servidor y queda cancelada', (t) async {
      final m = await _montar(
        t,
        responder: (_) => _json({
          'success': true,
          'data': {'accion_pendiente': _accionJson('cancelada')},
          'error': null,
          'meta': null,
        }, 200),
      );

      await t.tap(find.text('Cancelar'));
      await _asentar(t);

      expect(m.al('/cancelar'), hasLength(1));
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Cancelaste esta transferencia.'), findsOneWidget);
    });

    testWidgets('ActionExpired la deja vencida y sugiere pedirla de nuevo', (
      t,
    ) async {
      await _montar(t, responder: (_) => _fallo(410, 'ActionExpired'));

      await t.tap(find.text('Confirmar'));
      await _asentar(t);

      expect(find.text('Vencida'), findsOneWidget);
      expect(
        find.text(
          'Esta transferencia venció. Pídele a Vera que la prepare de nuevo.',
        ),
        findsOneWidget,
      );
    });

    for (final (codigo, texto) in [
      ('InsufficientFunds', 'No tienes saldo suficiente para esta operación.'),
      (
        'OperationLimitExceeded',
        'El monto supera el límite permitido por operación.',
      ),
      ('MonthlyQuotaExceeded', 'Superaste tu límite mensual de operaciones.'),
      (
        'RecipientNotFound',
        'No encontramos al destinatario. Revisa los datos.',
      ),
      ('SelfTransferNotAllowed', 'No puedes enviarte dinero a ti mismo.'),
    ]) {
      testWidgets('$codigo la deja fallida con su motivo', (t) async {
        await _montar(t, responder: (_) => _fallo(422, codigo));

        await t.tap(find.text('Confirmar'));
        await _asentar(t);

        expect(find.text('Fallida'), findsOneWidget);
        expect(find.text(texto), findsOneWidget);
        expect(find.text('Confirmar'), findsNothing);
      });
    }
  });

  group('doble toque y fallas de red', () {
    testWidgets('un doble toque durante el envío hace una sola confirmación', (
      t,
    ) async {
      final espera = Completer<http.Response>();
      final vistos = <http.Request>[];
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final mock = MockClient((r) {
        vistos.add(r);
        return espera.future;
      });
      await t.pumpWidget(
        MaterialApp(
          home: _Anfitrion(
            inicial: AccionPendiente.fromJson(_accionJson('pendiente')),
            repo: AsistenteRepository(
              client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
            ),
            verificador: _VerificadorFalso(ResultadoVerificacion.exitosa),
          ),
        ),
      );
      await t.tap(find.text('Confirmar'));
      await t.pump();
      await t.pump();
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      await t.pump();

      expect(
        vistos.where((r) => r.url.path.endsWith('/confirmar')),
        hasLength(1),
      );
      espera.complete(_confirmada());
      await _asentar(t);
    });

    testWidgets(
      'una falla de red reenvía la misma confirmación sin verificar otra vez',
      (t) async {
        var intentos = 0;
        final m = await _montar(
          t,
          responder: (_) {
            intentos++;
            if (intentos == 1) throw http.ClientException('sin red');
            return _confirmada();
          },
        );

        await t.tap(find.text('Confirmar'));
        await _asentar(t);
        expect(
          find.textContaining('es la misma confirmación y no se duplica'),
          findsOneWidget,
        );
        expect(find.text('Reintentar confirmación'), findsOneWidget);

        await t.tap(find.text('Reintentar confirmación'));
        await _asentar(t);

        expect(m.verificador.llamadas, 1);
        final envios = m.al('/confirmar').toList();
        expect(envios, hasLength(2));
        expect(envios[1].body, envios[0].body);
        expect(find.text('Transferencia enviada.'), findsOneWidget);
      },
    );

    testWidgets('un 503 también reenvía la misma confirmación', (t) async {
      var intentos = 0;
      final m = await _montar(
        t,
        responder: (_) {
          intentos++;
          return intentos == 1
              ? _fallo(503, 'AssistantUnavailable')
              : _confirmada();
        },
      );

      await t.tap(find.text('Confirmar'));
      await _asentar(t);
      await t.tap(find.text('Reintentar confirmación'));
      await _asentar(t);

      expect(m.al('/confirmar'), hasLength(2));
      expect(find.text('Transferencia enviada.'), findsOneWidget);
    });
  });
}
