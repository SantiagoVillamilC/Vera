import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Inteligencia de mentira: devuelve el resumen que se le dé, sin tocar la red.
class FakeInteligenciaRepository implements InteligenciaRepository {
  FakeInteligenciaRepository({this.onResumen});

  Future<ResumenDelMes> Function(String? mes)? onResumen;
  int resumenCalls = 0;
  final meses = <String?>[];

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GastoDeCategoria gasto(String nombre, int pesos) => GastoDeCategoria(
  codigo: nombre.toLowerCase(),
  nombre: nombre,
  totalCentavos: BigInt.from(pesos * 100),
);
