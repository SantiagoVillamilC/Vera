import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/asistente_screen.dart';

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

/// Respuesta de GET /v1/auth/consents?tipo=asistente_ia con la forma [data].
AsistenteRepository _repoConData(Object? data) => AsistenteRepository(
  client: ApiClient(
    baseUrl: 'http://x',
    clientFactory: () => MockClient(
      (_) async => _json({
        'success': true,
        'data': data,
        'error': null,
        'meta': null,
      }),
    ),
  ),
);

void main() {
  test('el contrato filtrado devuelve el objeto vigente', () async {
    final c = await _repoConData({
      'tipo': 'asistente_ia',
      'version_texto': 'v1',
      'texto': 'Vera usa IA para ayudarte.',
      'autorizado': false,
    }).consultarConsentimiento();

    expect(c.versionTexto, 'v1');
    expect(c.texto, 'Vera usa IA para ayudarte.');
    expect(c.autorizado, isFalse);
  });

  test('la lista vacía de un servidor sin el contrato falla como NotImplemented', () async {
    await expectLater(
      _repoConData(const []).consultarConsentimiento(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'NotImplemented'),
      ),
    );
  });

  test('data nula falla como NotImplemented', () async {
    await expectLater(
      _repoConData(null).consultarConsentimiento(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'NotImplemented'),
      ),
    );
  });

  testWidgets('sin el contrato la pantalla lo explica y no se rompe', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: AsistenteScreen(repository: _repoConData(const [])),
      ),
    );
    await t.pump();
    await t.pump();

    expect(find.text('Esta función aún no está disponible.'), findsOneWidget);
    expect(find.text('Activa a Vera'), findsNothing);
    expect(find.text('Algo salió mal. Intenta de nuevo en unos minutos.'), findsNothing);
  });
}
