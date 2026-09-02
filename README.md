# Repositorio: App móvil (Flutter / Dart)

Este documento describe la estructura de carpetas del repositorio de la app.

## Estructura de carpetas

```graphql
app/
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart          # Único punto de salida hacia el backend (HTTP)
│   │   │   └── api_exception.dart       # Tipo de error estándar para respuestas fallidas
│   │   ├── auth/
│   │   │   ├── pin_storage.dart         # Guarda el PIN de forma segura (flutter_secure_storage)
│   │   │   ├── token_storage.dart       # Guarda el JWT de sesión de forma segura
│   │   │   └── dynamic_key.dart         # Muestra/genera la clave dinámica (TOTP) tras iniciar sesión
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   └── app_theme.dart
│   │   └── widgets/
│   │       ├── primary_button.dart
│   │       ├── loading_indicator.dart
│   │       └── error_banner.dart
│   │
│   └── features/
│       ├── auth/
│       │   ├── login_screen.dart
│       │   ├── pin_screen.dart
│       │   ├── register_screen.dart
│       │   └── auth_service.dart
│       │
│       ├── copilot/
│       │   ├── chat_screen.dart
│       │   ├── chat_message.dart        # Modelo de un mensaje del chat (user/ai)
│       │   └── copilot_service.dart     # Llama a POST /copilot
│       │
│       ├── wallets/
│       │   ├── wallets_screen.dart
│       │   ├── wallet_model.dart
│       │   └── wallets_service.dart     # Llama a GET /wallets
│       │
│       ├── transfers/
│       │   ├── transfer_screen.dart
│       │   ├── auth_confirm_widget.dart # Prompt de huella/PIN antes de confirmar
│       │   ├── transfers_service.dart   # Llama a POST /transactions
│       │   └── realtime_listener.dart   # Suscripción a Supabase Realtime (saldo en vivo)
│       │
│       └── receipts/
│           ├── scan_screen.dart
│           ├── receipt_model.dart
│           └── receipts_service.dart    # Sube la foto, llama a POST /receipts
│
├── test/
│   └── (pruebas unitarias - una carpeta espejo de lib/features/)
│
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Dependencias sugeridas (`pubspec.yaml`)

| Paquete | Para qué |
| --- | --- |
| `dio` | Cliente HTTP hacia el backend |
| `flutter_secure_storage` | Guardar PIN y token de forma segura en el dispositivo |
| `provider` o `flutter_riverpod` | Manejo de estado |
| `supabase_flutter` | Únicamente para la suscripción a Realtime (lectura) - nunca para escribir datos directamente |
| `local_auth` | Para pedir huella/Face ID en la confirmación de transacciones |
| `image_picker` | Para tomar la foto de la factura |

---

## Ejemplo de referencia - cómo debe verse un `*_service.dart`

```dart
// lib/features/transfers/transfers_service.dart
import '../../core/network/api_client.dart';

class TransfersService {
  final ApiClient _apiClient;
  TransfersService(this._apiClient);

  Future<TransferResult> sendTransfer({
    required String to,
    required int amount,
    required String wallet,
  }) async {
    // Validación local de formato únicamente - el backend vuelve a validar todo.
    if (amount <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero');
    }

    final response = await _apiClient.post('/transactions', body: {
      'action': 'transfer',
      'to': to,
      'amount': amount,
      'wallet': wallet,
    });

    return TransferResult.fromJson(response);
  }
}
```

Este patrón - servicio delgado, validación solo de formato, todo lo demás vía `ApiClient` - debe repetirse en cada `*_service.dart` del proyecto.
