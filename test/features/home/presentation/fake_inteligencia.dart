import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Inteligencia de mentira: devuelve el resumen que se le dé, sin tocar la red.
class FakeInteligenciaRepository implements InteligenciaRepository {
  FakeInteligenciaRepository({this.onResumen, this.onAvisos});

  Future<ResumenDelMes> Function(String? mes)? onResumen;
  int resumenCalls = 0;
  final meses = <String?>[];

  /// Avisos por mes pedido: `null` es la bandeja del mes en curso.
  Future<List<Aviso>> Function(String? mes)? onAvisos;
  final mesesDeAvisos = <String?>[];
  final descartados = <String>[];
  ApiException? errorAlDescartar;

  @override
  Future<ResumenDelMes> resumen({String? mes}) {
    resumenCalls++;
    meses.add(mes);
    return onResumen?.call(mes) ??
        Future.value(
          ResumenDelMes(
            mes: '2026-10',
            totalCentavos: BigInt.zero,
            categorias: const [],
          ),
        );
  }

  @override
  Future<List<Aviso>> listarAvisos({String? mes}) {
    mesesDeAvisos.add(mes);
    return onAvisos?.call(mes) ?? Future.value(const []);
  }

  @override
  Future<AvisoDescartado> descartarAviso(String id) async {
    final error = errorAlDescartar;
    if (error != null) throw error;
    descartados.add(id);
    return AvisoDescartado(
      id: id,
      descartadoEn: DateTime.utc(2026, 11, 19, 17),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GastoDeCategoria gasto(String nombre, int pesos) => GastoDeCategoria(
  codigo: nombre.toLowerCase(),
  nombre: nombre,
  totalCentavos: BigInt.from(pesos * 100),
);
