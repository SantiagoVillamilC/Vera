class AppConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Muestra en la bandeja de avisos el indicador «n de N» y el aviso de tope.
  /// Apagado por defecto: se enciende con
  /// `--dart-define=MOSTRAR_CUPO_AVISOS=true`.
  static const mostrarCupoAvisos = bool.fromEnvironment(
    'MOSTRAR_CUPO_AVISOS',
  );
}
