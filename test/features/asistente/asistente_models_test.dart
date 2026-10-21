import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

// Ejemplos tomados de api/openapi.yaml (tag asistente).
const _accion = {
  'id': '0a1b2c3d-0000-4000-8000-000000000009',
  'estado': 'pendiente',
  'tipo': 'transferencia_interna',
  'destinatario': {'nombre': 'Laura R.', 'celular_parcial': '******4321'},
  'monto': '150000',
  'moneda': 'COP',
  'requiere_codigo': true,
  'expira_en': '2026-10-15T14:21:00-05:00',
};

void main() {
  group('RespuestaAsistente', () {
    test('voz: trae transcripcion y sin accion', () {
      final r = RespuestaAsistente.fromJson({
        'conversacion_id': 'c1',
        'mensaje_id': 'm1',
        'texto': 'Tienes disponibles \$1.250.000 en tu cuenta.',
        'transcripcion': 'cuanto tengo disponible',
        'creado_en': '2026-10-15T14:17:00-05:00',
      });
      expect(r.transcripcion, 'cuanto tengo disponible');
      expect(r.accionPendiente, isNull);
    });

    test('accion pendiente: monto en centavos y destinatario', () {
      final r = RespuestaAsistente.fromJson({
        'conversacion_id': 'c1',
        'mensaje_id': 'm2',
        'texto': 'Listo',
        'creado_en': '2026-10-15T14:16:00-05:00',
        'accion_pendiente': _accion,
      });
      final a = r.accionPendiente!;
      expect(a.montoCentavos, BigInt.from(150000));
      expect(a.estado, EstadoAccion.pendiente);
      expect(a.tipo, TipoAccion.transferenciaInterna);
      expect(a.destinatario!.nombre, 'Laura R.');
      expect(a.requiereCodigo, isTrue);
    });
  });

  test('AccionPendiente llave: destinatario null', () {
    final a = AccionPendiente.fromJson({
      ..._accion,
      'tipo': 'transferencia_llave',
      'destinatario': null,
      'llave': '@laura',
      'tipo_llave': 'alfanumerico',
    });
    expect(a.destinatario, isNull);
    expect(a.llave, '@laura');
    expect(a.tipo, TipoAccion.transferenciaLlave);
  });

  test('AccionResuelta con transferencia', () {
    final r = AccionResuelta.fromJson({
      'accion_pendiente': {..._accion, 'estado': 'confirmada'},
      'transferencia': {
        'id': 't1',
        'destino': '3001234321',
        'monto': '150000',
        'moneda': 'COP',
        'estado': 'confirmada',
        'creada_en': '2026-10-15T14:18:00-05:00',
        'actualizada_en': '2026-10-15T14:18:05-05:00',
      },
    });
    expect(r.accion.estado, EstadoAccion.confirmada);
    expect(r.transferencia!.montoCentavos, BigInt.from(150000));
  });

  test('PaginaVera de mensajes lee meta y roles', () {
    final p = PaginaVera.fromEnvelope({
      'data': [
        {
          'id': 'm1',
          'rol': 'usuario',
          'canal': 'voz',
          'texto': 'hola',
          'creado_en': '2026-10-15T14:15:50-05:00',
        },
      ],
      'meta': {'limit': 50, 'next_cursor': 7, 'has_more': true},
    }, MensajeVera.fromJson);
    expect(p.items.single.rol, RolMensaje.usuario);
    expect(p.items.single.canal, CanalMensaje.voz);
    expect(p.nextCursor, 7);
    expect(p.hasMore, isTrue);
  });

  test('enviarVoz rechaza audio vacio o mayor a 700 KB antes de llamar', () {
    final repo = AsistenteRepository();
    expect(
      () => repo.enviarVoz(audioM4a: Uint8List(0)),
      throwsA(isA<AudioFueraDeLimiteException>()),
    );
    expect(
      () => repo.enviarVoz(audioM4a: Uint8List(LimitesAudio.maxBytes + 1)),
      throwsA(isA<AudioFueraDeLimiteException>()),
    );
  });
}
