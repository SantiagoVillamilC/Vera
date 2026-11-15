import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/presentation/destino_de_aviso.dart';

/// Detalle de un aviso: una sola pantalla que se adapta al tipo.
///
/// La bandeja pasa el [aviso] que ya tiene, así que no hay llamada nueva. Solo
/// se pide `GET /v1/inteligencia/avisos/{id}` al entrar por enlace directo.
class DetalleAvisoScreen extends StatefulWidget {
  const DetalleAvisoScreen({
    super.key,
    this.aviso,
    this.avisoId,
    this.repository,
    this.ahora,
  }) : assert(
         aviso != null || avisoId != null,
         'hace falta el aviso o su id',
       );

  /// El aviso que trae la bandeja. Con él no se llama a la red.
  final Aviso? aviso;

  /// Id para pedirlo cuando se llega sin el objeto.
  final String? avisoId;

  /// Por defecto el repositorio real.
  final InteligenciaRepository? repository;

  /// Solo para pruebas: reloj fijo en lugar del del equipo.
  final DateTime? ahora;

  @override
  State<DetalleAvisoScreen> createState() => _DetalleAvisoScreenState();
}

class _DetalleAvisoScreenState extends State<DetalleAvisoScreen> {
  late final InteligenciaRepository _repo =
      widget.repository ?? InteligenciaRepository();

  late Aviso? _aviso = widget.aviso;
  late bool _cargando = widget.aviso == null;
  Object? _error;
  bool _descartando = false;

  @override
  void initState() {
    super.initState();
    if (_aviso == null) _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final aviso = await _repo.obtenerAviso(widget.avisoId!);
      if (!mounted) return;
      setState(() {
        _aviso = aviso;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  /// Descarta y vuelve a la bandeja, que quita el aviso con el id devuelto.
  /// Si falla, el aviso se queda: aquí no hay nada que revertir en pantalla.
  Future<void> _descartar(Aviso aviso) async {
    if (_descartando) return;
    setState(() => _descartando = true);
    try {
      await _repo.descartarAviso(aviso.id);
      if (!mounted) return;
      context.pop(aviso.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _descartando = false);
      _avisar(
        e.code == codigoDescarteAnteriorAlAlta
            ? mensajeDescarteAnteriorAlAlta
            : mensajeDeError(e),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _descartando = false);
      _avisar(mensajeDeError(e));
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
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
    final aviso = _aviso;
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
            child: Text(
              'Aviso',
              style: TextStyle(
                color: context.paleta.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          // La prioridad es el único nivel que existe: la severidad es un monto
          // que solo ordena dentro de ella.
          if (aviso != null)
            Text(
              'Prioridad ${aviso.prioridad}',
              style: TextStyle(
                color: context.paleta.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const EstadoVista.cargando();
    final error = _error;
    if (error != null) {
      return EstadoVista.deError(
        error,
        key: const ValueKey('error-detalle-aviso'),
        mensaje: mensajeDeError(error),
        onReintentar: _cargar,
      );
    }
    final aviso = _aviso!;
    final rotulos = rotulosDe(aviso.tipo);
    final referencia = aviso.referenciaCentavos;
    final rotulo = rotuloDeAccion(aviso);
    final destino = destinoDe(aviso);
    final mesDelAviso = aviso.mes;
    final mesEnCurso = mesDeBogota(widget.ahora ?? DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        // Si el aviso es de otro mes se dice, porque su texto habla de ese mes.
        if (mesDelAviso.isNotEmpty && mesDelAviso != mesEnCurso)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Aviso de ${_mesLargo(mesDelAviso)}',
              key: const ValueKey('aviso-de-otro-mes'),
              style: TextStyle(
                color: context.paleta.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        Text(
          aviso.titulo,
          style: TextStyle(
            color: context.paleta.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          aviso.texto,
          style: TextStyle(
            color: context.paleta.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (aviso.porque.isNotEmpty) ...[
          TarjetaVidrio(
            radio: 20,
            opaca: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POR QUÉ',
                  style: TextStyle(
                    color: context.paleta.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  aviso.porque,
                  key: const ValueKey('porque-aviso'),
                  style: TextStyle(
                    color: context.paleta.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        TarjetaVidrio(
          radio: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Cifra(
                rotulo: rotulos.monto,
                valor: formatPesos(aviso.montoCentavos),
              ),
              // cobro_nuevo no trae línea base: la fila no se dibuja en vez de
              // mostrar un cero que nadie envió.
              if (referencia != null && rotulos.referencia != null) ...[
                const SizedBox(height: 10),
                _Cifra(
                  rotulo: rotulos.referencia!,
                  valor: formatPesos(referencia),
                ),
              ],
              if (aviso.periodo.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Cifra(
                  rotulo: rotulos.fecha,
                  valor: rotulos.fecha == 'Mes'
                      ? _mesLargo(aviso.mes)
                      : _fechaLarga(aviso.periodo),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (rotulo != null && destino != null)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const ValueKey('accion-principal'),
              onPressed: () => context.push(destino.ruta),
              style: TextButton.styleFrom(
                foregroundColor: context.paleta.tintaBotonClaro,
                backgroundColor: context.paleta.botonClaro,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                rotulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            key: const ValueKey('descartar-detalle'),
            onPressed: _descartando ? null : () => _descartar(aviso),
            style: TextButton.styleFrom(
              foregroundColor: context.paleta.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Descartar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// `YYYY-MM` como «noviembre de 2026».
String _mesLargo(String mes) {
  final partes = mes.split('-');
  if (partes.length < 2) return mes;
  final nombre = nombreDeMes(int.tryParse(partes[1]) ?? 0);
  return nombre.isEmpty ? mes : '$nombre de ${partes[0]}';
}

/// `YYYY-MM-DD` como «20 de noviembre de 2026». Se lee de la cadena: convertir
/// a hora local correría el día.
String _fechaLarga(String periodo) {
  final partes = periodo.split('-');
  if (partes.length < 3) return _mesLargo(periodo);
  final nombre = nombreDeMes(int.tryParse(partes[1]) ?? 0);
  final dia = int.tryParse(partes[2]);
  if (nombre.isEmpty || dia == null) return periodo;
  return '$dia de $nombre de ${partes[0]}';
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final estiloRotulo = TextStyle(color: paleta.textSecondary, fontSize: 14);
    final estiloValor = TextStyle(
      color: paleta.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final rotuloTexto = Text(rotulo, style: estiloRotulo);

    // Con la letra del sistema al máximo un peso como «$139.900» ocupa casi
    // todo el ancho y no deja sitio al rótulo. En vez de recortar la cifra,
    // que es el dato, el rótulo se pasa arriba.
    return LayoutBuilder(
      builder: (context, restricciones) {
        final escala = MediaQuery.textScalerOf(context);
        final pintor = TextPainter(
          text: TextSpan(text: valor, style: estiloValor),
          textScaler: escala,
          textDirection: Directionality.of(context),
        )..layout();
        final anchoValor = pintor.width;
        pintor.dispose();

        if (anchoValor <= restricciones.maxWidth / 2) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rotuloTexto),
              const SizedBox(width: 12),
              Text(valor, textAlign: TextAlign.right, style: estiloValor),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            rotuloTexto,
            const SizedBox(height: 2),
            Text(valor, style: estiloValor),
          ],
        );
      },
    );
  }
}
