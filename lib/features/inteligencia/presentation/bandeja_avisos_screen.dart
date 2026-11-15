import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/inteligencia/presentation/destino_de_aviso.dart';

/// Cuenta los avisos vigentes que vería la bandeja: el mes en curso más el
/// anterior. Es la fuente del contador de Inicio, para que el número y la
/// lista nunca se contradigan.
Future<int> contarAvisosVigentes(
  InteligenciaRepository repo, {
  DateTime? ahora,
}) async {
  final avisos = await _leerDosMeses(repo, ahora: ahora);
  return avisos.length;
}

/// La bandeja son dos llamadas: `caida_ingreso` pertenece al mes anterior y
/// solo sale con `?mes=`. Si la del mes anterior falla, no se pierde la del
/// mes en curso.
Future<List<Aviso>> _leerDosMeses(
  InteligenciaRepository repo, {
  DateTime? ahora,
  void Function(Object error)? alFallarElAnterior,
}) async {
  final mesPasado = mesAnterior(mesDeBogota(ahora ?? DateTime.now()));
  final enCurso = await repo.listarAvisos();
  List<Aviso> anteriores = const [];
  try {
    anteriores = await repo.listarAvisos(mes: mesPasado);
  } catch (e) {
    alFallarElAnterior?.call(e);
  }
  return [...enCurso, ...anteriores]..sort(Aviso.comparar);
}

/// Bandeja de avisos: la única pantalla nueva del flujo.
///
/// Lee los vigentes del mes en curso y del anterior, los ordena como el
/// servidor y permite descartarlos. La persistencia del descarte la garantiza
/// el servidor: aquí no se guarda nada.
class BandejaAvisosScreen extends StatefulWidget {
  const BandejaAvisosScreen({super.key, this.repository, this.ahora});

  /// Por defecto el repositorio real.
  final InteligenciaRepository? repository;

  /// Solo para pruebas: reloj fijo en lugar del del equipo.
  final DateTime? ahora;

  @override
  State<BandejaAvisosScreen> createState() => _BandejaAvisosScreenState();
}

class _BandejaAvisosScreenState extends State<BandejaAvisosScreen> {
  late final InteligenciaRepository _repo =
      widget.repository ?? InteligenciaRepository();

  bool _cargando = true;
  Object? _error;
  List<Aviso> _avisos = const [];
  ResumenDelMes? _resumen;

  /// Descarta respuestas de una carga anterior cuando se reinicia la lista.
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final gen = ++_generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final avisos = await _leerDosMeses(
        _repo,
        ahora: widget.ahora,
        alFallarElAnterior: (e) =>
            _avisar('No se pudo leer el mes anterior. ${mensajeDeError(e)}'),
      );
      // El cupo es informativo: si falla, la bandeja se muestra igual.
      ResumenDelMes? resumen;
      try {
        resumen = await _repo.resumen();
      } catch (_) {
        resumen = null;
      }
      if (!mounted || gen != _generacion) return;
      setState(() {
        _avisos = avisos;
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || gen != _generacion) return;
      if (_avisos.isEmpty) {
        setState(() {
          _error = e;
          _cargando = false;
        });
      } else {
        // Una recarga fallida no borra lo que el usuario ya está viendo.
        setState(() => _cargando = false);
        _avisar('No se pudo actualizar. ${mensajeDeError(e)}');
      }
    }
  }

  /// Abre el detalle con el aviso que ya se tiene y, si allí se descartó,
  /// lo quita de la lista y deja el contador de Inicio al día al volver.
  Future<void> _abrirDetalle(Aviso aviso) async {
    final descartado = await context.push<Object?>(
      '/avisos/${aviso.id}',
      extra: aviso,
    );
    if (!mounted || descartado is! String) return;
    setState(() {
      _avisos = [
        for (final a in _avisos)
          if (a.id != descartado) a,
      ];
    });
    _relerElCupo();
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Descarte optimista: el aviso sale de la lista al instante y vuelve si el
  /// POST falla.
  Future<void> _descartar(Aviso aviso) async {
    final antes = _avisos;
    setState(() {
      _avisos = [
        for (final a in _avisos)
          if (a.id != aviso.id) a,
      ];
    });
    try {
      await _repo.descartarAviso(aviso.id);
      if (!mounted) return;
      // El descarte libera cupo del periodo, así que el indicador cambia.
      _relerElCupo();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _avisos = antes);
      _avisar(
        e.code == codigoDescarteAnteriorAlAlta
            ? mensajeDescarteAnteriorAlAlta
            : mensajeDeError(e),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _avisos = antes);
      _avisar(mensajeDeError(e));
    }
  }

  /// Relee el cupo sin bloquear ni romper el descarte si falla.
  void _relerElCupo() {
    _repo
        .resumen()
        .then((r) {
          if (mounted) setState(() => _resumen = r);
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.paleta.background,
      body: FondoVera(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezado(context),
              const SizedBox(height: 8),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final resumen = _resumen;
    final emitidos = resumen?.avisosEmitidos;
    final cupo = resumen?.cupoAvisos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Volver',
            excludeSemantics: true,
            onTap: () => context.canPop() ? context.pop() : null,
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: context.paleta.botonOscuro,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.paleta.borderGlass),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: context.paleta.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Avisos',
                    maxLines: 1,
                    style: TextStyle(
                      color: context.paleta.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Text(
                  'Lo que Vera notó en tu plata',
                  style: TextStyle(
                    color: context.paleta.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          // «n de N» con los valores del servidor: el cupo se configura por
          // entorno, así que la app no fija el número.
          if (emitidos != null && cupo != null)
            Container(
              key: const ValueKey('indicador-cupo'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.paleta.surfaceVariant,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.paleta.border),
              ),
              child: Text(
                '$emitidos de $cupo',
                style: TextStyle(
                  color: context.paleta.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _avisos.isEmpty) return const EstadoVista.cargando();
    final error = _error;
    if (error != null && _avisos.isEmpty) {
      return EstadoVista.deError(
        error,
        key: const ValueKey('error-avisos'),
        mensaje: mensajeDeError(error),
        onReintentar: _cargar,
      );
    }
    if (_avisos.isEmpty) {
      return const EstadoVista.vacio(
        key: ValueKey('avisos-vacio'),
        mensaje: 'Sin avisos este mes.',
      );
    }

    final enCurso = mesDeBogota(widget.ahora ?? DateTime.now());
    final grupos = <String, List<Aviso>>{};
    for (final a in _avisos) {
      grupos.putIfAbsent(a.mes, () => []).add(a);
    }
    final meses = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: context.paleta.gradientStart,
      backgroundColor: context.paleta.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          if (_resumen?.cupoLleno ?? false) const _AvisoDeCupoLleno(),
          for (final mes in meses) ...[
            _TituloDeMes(mes: mes, esElMesEnCurso: mes == enCurso),
            for (final aviso in grupos[mes]!)
              _TarjetaDeAviso(
                aviso: aviso,
                onAbrir: () => _abrirDetalle(aviso),
                onDescartar: () => _descartar(aviso),
              ),
          ],
        ],
      ),
    );
  }
}

class _TituloDeMes extends StatelessWidget {
  const _TituloDeMes({required this.mes, required this.esElMesEnCurso});

  final String mes;
  final bool esElMesEnCurso;

  @override
  Widget build(BuildContext context) {
    final partes = mes.split('-');
    final nombre = partes.length == 2
        ? nombreDeMes(int.tryParse(partes[1]) ?? 0)
        : mes;
    // nombreDeMes devuelve minúscula; este es un encabezado de sección.
    final titulo = nombre.isEmpty
        ? mes
        : '${nombre[0].toUpperCase()}${nombre.substring(1)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        esElMesEnCurso ? '$titulo · mes en curso' : '$titulo · mes anterior',
        key: ValueKey('mes-$mes'),
        style: TextStyle(
          color: context.paleta.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AvisoDeCupoLleno extends StatelessWidget {
  const _AvisoDeCupoLleno();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TarjetaVidrio(
        key: const ValueKey('cupo-lleno'),
        radio: 20,
        opaca: true,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 18,
              color: context.paleta.textSecondary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Llegaste al tope de avisos de este mes. Descartar uno libera '
                'espacio para el siguiente.',
                style: TextStyle(
                  color: context.paleta.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaDeAviso extends StatelessWidget {
  const _TarjetaDeAviso({
    required this.aviso,
    required this.onAbrir,
    required this.onDescartar,
  });

  final Aviso aviso;
  final VoidCallback onAbrir;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaVidrio(
        key: ValueKey('aviso-${aviso.id}'),
        radio: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '${aviso.titulo}. Ver el detalle',
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('abrir-${aviso.id}'),
                onTap: onAbrir,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aviso.titulo,
                      style: TextStyle(
                        color: context.paleta.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      aviso.texto,
                      style: TextStyle(
                        color: context.paleta.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Sin accion_codigo conocido no hay destino que abrir, así que
                // la tarjeta se muestra sin botón de acción.
                if (rotuloDeAccion(aviso) case final rotulo?)
                  TextButton(
                    key: ValueKey('accion-${aviso.id}'),
                    onPressed: () =>
                        context.push(destinoDe(aviso)!.ruta),
                    style: TextButton.styleFrom(
                      foregroundColor: context.paleta.tintaBotonClaro,
                      backgroundColor: context.paleta.botonClaro,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      rotulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                // El botón dice solo «Descartar» porque al lado se ve de qué
                // aviso es. Quien usa lector de pantalla no lo ve, y oiría
                // «Descartar» repetido una vez por aviso: la etiqueta nombra
                // cuál se va a descartar.
                Semantics(
                  button: true,
                  label: 'Descartar: ${aviso.titulo}',
                  excludeSemantics: true,
                  onTap: onDescartar,
                  child: TextButton(
                    key: ValueKey('descartar-${aviso.id}'),
                    onPressed: onDescartar,
                    style: TextButton.styleFrom(
                      foregroundColor: context.paleta.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Descartar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
