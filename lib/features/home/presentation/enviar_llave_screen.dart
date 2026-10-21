import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/llave_bre_b.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Cualquier 2xx que no sea un fallo inmediato. Nunca afirma que el dinero
/// llegó: el resultado real se ve en el historial.
const mensajeLlaveEnviado = 'Enviado. Verás el resultado en tu historial.';

const mensajeLlaveFallida =
    'El envío no se completó. Revisa tu historial para ver el detalle.';
const mensajeLlaveCompensada =
    'El envío no se completó y el dinero volvió a tu saldo. Revisa tu historial para ver el detalle.';
const mensajeLlaveConexion = 'Error de conexión. Intenta de nuevo.';
const mensajeLlaveNoEncontrada =
    'No encontramos esa llave. Revisa el dato e intenta de nuevo.';

String _etiquetaDeTipo(TipoLlaveBreB tipo) => switch (tipo) {
      TipoLlaveBreB.documento => 'Documento',
      TipoLlaveBreB.celular => 'Celular',
      TipoLlaveBreB.correo => 'Correo',
      TipoLlaveBreB.alfanumerico => 'Alfanumérica',
      TipoLlaveBreB.comercio => 'Comercio',
    };

String _pistaDeTipo(TipoLlaveBreB tipo) => switch (tipo) {
      TipoLlaveBreB.documento => '1234567890',
      TipoLlaveBreB.celular => '3001234567',
      TipoLlaveBreB.correo => 'nombre@correo.com',
      TipoLlaveBreB.alfanumerico => '@minombre',
      TipoLlaveBreB.comercio => 'ABC123',
    };

String _errorDeTipo(TipoLlaveBreB tipo) => switch (tipo) {
      TipoLlaveBreB.documento => 'El documento debe tener entre 6 y 10 dígitos.',
      TipoLlaveBreB.celular =>
        'El celular debe tener 10 dígitos y empezar por 3, sin +57.',
      TipoLlaveBreB.correo => 'Escribe un correo válido.',
      TipoLlaveBreB.alfanumerico =>
        'La llave alfanumérica empieza por @ y lleva solo letras y números.',
      TipoLlaveBreB.comercio =>
        'La llave de comercio lleva entre 6 y 20 letras o números.',
    };

TextInputType _tecladoDeTipo(TipoLlaveBreB tipo) => switch (tipo) {
      TipoLlaveBreB.documento || TipoLlaveBreB.celular => TextInputType.number,
      TipoLlaveBreB.correo => TextInputType.emailAddress,
      _ => TextInputType.text,
    };

/// Mensaje de un fallo al enviar por llave. Un 404 es una llave inexistente.
String _mensajeDeFallo(Object error) {
  if (esErrorDeRed(error)) return mensajeLlaveConexion;
  if (error is ApiException &&
      (error.code == 'NotFound' || error.code == 'RecipientNotFound')) {
    return mensajeLlaveNoEncontrada;
  }
  return mensajeDeError(error);
}

bool _esFalloDeServidor(Object error) {
  if (error is! ApiException) return false;
  final s = error.statusCode;
  return s != null && s >= 500;
}

class EnviarLlaveScreen extends StatefulWidget {
  const EnviarLlaveScreen({super.key, this.repository, this.intent});

  /// Por defecto las dependencias reales. Se inyectan para pruebas.
  final NucleoRepository? repository;

  /// Intención propia de este flujo, separada de la recarga y del envío interno.
  final IdempotencyIntent? intent;

  @override
  State<EnviarLlaveScreen> createState() => _EnviarLlaveScreenState();
}

class _EnviarLlaveScreenState extends State<EnviarLlaveScreen> {
  final _llaveCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  late final NucleoRepository _repo = widget.repository ?? NucleoRepository();
  late final IdempotencyIntent _intent = widget.intent ?? IdempotencyIntent();

  TipoLlaveBreB _tipo = TipoLlaveBreB.celular;
  bool _enviando = false;
  String? _error;
  bool _reintentable = false;
  String? _resultado;
  bool _resultadoExitoso = false;

  @override
  void dispose() {
    _llaveCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  BigInt? get _montoCentavos {
    final limpio = _montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final pesos = BigInt.tryParse(limpio);
    if (pesos == null) return null;
    return pesos * BigInt.from(100);
  }

  String? get _llave => normalizarLlave(_tipo, _llaveCtrl.text);

  bool get _puedeEnviar {
    final m = _montoCentavos;
    return !_enviando && _llave != null && m != null && m > BigInt.zero;
  }

  bool get _llaveInvalida =>
      _llaveCtrl.text.trim().isNotEmpty && _llave == null;

  Future<void> _enviar() async {
    final llave = _llave;
    final monto = _montoCentavos;
    if (_enviando || llave == null || monto == null || monto <= BigInt.zero) {
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
      _reintentable = false;
      _resultado = null;
    });
    try {
      final key = _intent.keyFor(
        destino: '${_tipo.codigo}:$llave',
        monto: monto,
      );
      final envio = await _repo.transferirInterbancaria(
        tipoLlave: _tipo.codigo,
        llave: llave,
        monto: monto.toString(),
        idempotencyKey: key,
      );
      _intent.registrarExito();
      if (!mounted) return;
      final (mensaje, exitoso) = switch (envio.estado) {
        EstadoTransferencia.fallida => (mensajeLlaveFallida, false),
        EstadoTransferencia.compensada => (mensajeLlaveCompensada, false),
        EstadoTransferencia.indeterminada ||
        EstadoTransferencia.desconocido =>
          (mensajeLlaveEnviado, false),
        _ => (mensajeLlaveEnviado, true),
      };
      setState(() {
        _enviando = false;
        _llaveCtrl.clear();
        _montoCtrl.clear();
        _resultado = mensaje;
        _resultadoExitoso = exitoso;
      });
    } on Object catch (e) {
      _intent.registrarError(e);
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = _mensajeDeFallo(e);
        _reintentable = _esFalloDeServidor(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Enviar por llave',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Tarjeta(child: _selectorDeTipo()),
            const SizedBox(height: 8),
            _Tarjeta(child: _campoLlave()),
            const SizedBox(height: 8),
            _Tarjeta(child: _campoMonto()),
            if (_resultado != null) ...[
              const SizedBox(height: 16),
              _avisoDeResultado(_resultado!, _resultadoExitoso),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('error-envio'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
              if (_reintentable)
                TextButton(
                  key: const Key('reintentar'),
                  onPressed: _enviando ? null : _enviar,
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(color: AppColors.gradientStart),
                  ),
                ),
            ],
            const SizedBox(height: 32),
            GradientButton(
              key: const Key('enviar'),
              label: 'Enviar',
              icon: Icons.send_rounded,
              loading: _enviando,
              onPressed: _puedeEnviar ? _enviar : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _selectorDeTipo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de llave',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tipo in TipoLlaveBreB.values)
              ChoiceChip(
                key: Key('tipo-${tipo.codigo}'),
                label: Text(_etiquetaDeTipo(tipo)),
                selected: _tipo == tipo,
                onSelected:
                    _enviando ? null : (_) => setState(() => _tipo = tipo),
              ),
          ],
        ),
      ],
    );
  }

  Widget _campoLlave() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Llave',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('llave'),
          controller: _llaveCtrl,
          enabled: !_enviando,
          keyboardType: _tecladoDeTipo(_tipo),
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(254)],
          style: const TextStyle(
            color: AppColors.gradientStart,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: _pistaDeTipo(_tipo),
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (_llaveInvalida) ...[
          const SizedBox(height: 8),
          Text(
            _errorDeTipo(_tipo),
            key: const Key('llave-error'),
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _campoMonto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monto en pesos (COP)',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('monto'),
          controller: _montoCtrl,
          enabled: !_enviando,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(17),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: '\$0',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _avisoDeResultado(String mensaje, bool exitoso) {
    final color = exitoso ? AppColors.accentGreen : AppColors.warning;
    return Container(
      key: const Key('resultado'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 15),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
