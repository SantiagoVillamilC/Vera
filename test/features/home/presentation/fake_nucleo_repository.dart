import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Fake compartido por las pruebas de home y movimientos. Cuenta las llamadas
/// a través de reconstrucciones para detectar peticiones repetidas.
class FakeNucleoRepository implements NucleoRepository {
  Future<MontoCalculado> Function() onSaldo = () async => MontoCalculado(
        montoCentavos: BigInt.from(18000000),
        moneda: 'COP',
        calculadoEn: DateTime.utc(2026),
      );

  Future<MovimientosPage> Function(int limit, int? cursor) onMovimientos =
      (limit, cursor) async => pagina(const []);

  Future<KycEstado> Function() onKyc = () async => const KycEstado(
        producto: 'bajo_monto',
        estadoKyc: 'basico',
      );

  int saldoCalls = 0;
  int kycCalls = 0;
  final movimientosCalls = <({int limit, int? cursor})>[];

  @override
  Future<MontoCalculado> getSaldo() {
    saldoCalls++;
    return onSaldo();
  }

  @override
  Future<KycEstado> getKycEstado() {
    kycCalls++;
    return onKyc();
  }

  @override
  Future<MovimientosPage> getMovimientos({int limit = 50, int? cursor}) {
    movimientosCalls.add((limit: limit, cursor: cursor));
    return onMovimientos(limit, cursor);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MovimientosPage pagina(
  List<Movimiento> items, {
  int? nextCursor,
  bool hasMore = false,
}) =>
    MovimientosPage(items: items, nextCursor: nextCursor, hasMore: hasMore);

/// Movimiento con líneas (motivo, centavos con signo).
Movimiento mov(
  int id,
  List<(MotivoLinea, int)> lineas, {
  DateTime? ocurridoEn,
}) {
  final cuando = ocurridoEn ?? DateTime.now().toUtc();
  return Movimiento(
    entryId: id,
    ocurridoEn: cuando,
    registradoEn: cuando,
    moneda: 'COP',
    lineas: [
      for (final (motivo, c) in lineas)
        LineaMovimiento(montoCentavos: BigInt.from(c), motivo: motivo),
    ],
  );
}

/// Transferencia compensada: salida, GMF, devolución y devolución del GMF.
Movimiento movCompensado(int id, {DateTime? ocurridoEn}) => mov(
      id,
      [
        (MotivoLinea.envio, -1000000),
        (MotivoLinea.gravamen, -4000),
        (MotivoLinea.devolucion, 1000000),
        (MotivoLinea.devolucionGravamen, 4000),
      ],
      ocurridoEn: ocurridoEn,
    );
