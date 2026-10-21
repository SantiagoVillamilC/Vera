import 'package:url_launcher/url_launcher.dart';

/// Abre una URL fuera de la app. Es inyectable para que las pruebas nunca
/// toquen el plugin.
abstract interface class UrlOpener {
  /// Devuelve true si el sistema logró abrir la URL.
  Future<bool> abrir(Uri uri);
}

class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> abrir(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Instancia por defecto que usan las pantallas.
const UrlOpener defaultUrlOpener = UrlLauncherOpener();

/// Interpreta la URL de pago del servidor. Solo admite http y https con host,
/// cualquier otra cosa (javascript:, intent:, file:, vacío) devuelve null.
Uri? urlPagoSegura(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final esquema = uri.scheme.toLowerCase();
  if (esquema != 'http' && esquema != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}
