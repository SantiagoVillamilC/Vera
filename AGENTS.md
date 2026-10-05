# Vera — Agent Guide

Flutter mobile app — billetera digital para Colombia.
Dart SDK ^3.12, Material 3, **dark-only theme**.

---

## Stack

| Layer | Package | Notes |
|---|---|---|
| State management | `flutter_riverpod` 2.x + `riverpod_annotation` | Always use code gen |
| Navigation | `go_router` 14.x | Entry point: `/login` |
| Typography | `google_fonts` 6.x | Playfair Display en el logo |
| Code generation | `build_runner` + `riverpod_generator` | Run after every `@riverpod` change |
| HTTP | `package:http` or `dio` | Not yet added — add when connecting backend |

---

## Commands

```bash
flutter run -d C27183E2-4101-4121-9F96-55E687DA80C8   # iOS simulator (iPhone 17 Pro)
flutter run -d <device-id>                             # any device
flutter devices                                        # list devices
dart run build_runner build --delete-conflicting-outputs  # generate Riverpod code
dart run build_runner watch --delete-conflicting-outputs  # watch mode
flutter analyze                                        # must return "No issues found"
flutter test                                           # unit + widget tests
flutter test --coverage                                # LCOV coverage
```

**Always run `build_runner build` after adding or modifying `@riverpod` annotated classes.**

---

## Project layout

```
lib/
├── main.dart                              # ProviderScope + runApp
├── app/
│   ├── app.dart                           # MaterialApp.router, dark-only
│   └── router.dart                        # all GoRouter routes
├── core/
│   ├── theme/
│   │   ├── app_theme.dart                 # AppColors, AppGradients, ThemeData
│   │   ├── theme_provider.dart            # AppThemeMode @riverpod notifier
│   │   └── theme_provider.g.dart          # generated — do not edit
│   └── widgets/
│       ├── auth_background.dart           # dark scaffold with radial glow blobs
│       ├── gradient_button.dart           # brand gradient CTA button
│       ├── pin_pad.dart                   # PinDots + NumPad for PIN/OTP entry
│       ├── vera_animated_logo.dart        # animated 3-card accordion logo
│       └── vera_logo.dart                 # simple text logo
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── login_screen.dart          # LoginScreen, PinScreen, OtpLoginScreen
    │       └── register_screen.dart       # RegisterScreen + OtpRegisterScreen
    └── home/
        └── presentation/
            └── home_screen.dart           # post-login placeholder
```

---

## Design system

All tokens live in `lib/core/theme/app_theme.dart`.

### Key colors

```dart
AppColors.background      // #07080F  — main scaffold bg
AppColors.surface         // #0F1020  — cards
AppColors.surfaceVariant  // #161829  — inputs, chips
AppColors.gradientStart   // #7B5EA7  — brand gradient start
AppColors.gradientMid     // #6C4FD9  — brand gradient mid
AppColors.gradientEnd     // #4B3BC4  — brand gradient end
AppColors.accent          // #00D4FF  — cyan accent
AppColors.accentGreen     // #00E5A0  — success green
AppColors.error           // #FF5B79
AppColors.textPrimary     // #FFFFFF
AppColors.textSecondary   // #8B8FAD
AppColors.textMuted       // #454761
AppColors.border          // #1E2038
```

### Gradients

```dart
AppGradients.brand         // horizontal #7B5EA7 → #4B3BC4
AppGradients.brandVertical // vertical
AppGradients.card          // dark card gradient
```

### Shared widgets

| Widget | Props | Notes |
|---|---|---|
| `AuthBackground` | `child` | Wraps all auth screens |
| `GradientButton` | `label`, `onPressed`, `loading`, `icon` | `onPressed: null` = disabled state |
| `PinDots` | `length`, `filled` | Animated dot indicators |
| `NumPad` | `onDigit`, `onDelete`, `onBiometric` | Circular keypad with haptics |
| `VeraAnimatedLogo` | — | Full logo: 3-card accordion + Playfair Display text |
| `VeraCardIcon` | `size` | Compact animated icon for sub-screens |

---

## Routes

Entry point is `/login` — no landing page.

| Route | Widget | `extra` type |
|---|---|---|
| `/login` | `LoginScreen` | — |
| `/login/pin` | `PinScreen` | `String` (phone) |
| `/login/otp` | `OtpLoginScreen` | `Map<String, dynamic>` {phone, challengeId} |
| `/register` | `RegisterScreen` | — |
| `/home` | `HomeScreen` | — |

```dart
context.go('/path');              // replace current route
context.push('/path', extra: x); // push with extra data
```

---

## Authentication flow

### Login (3 screens)
1. `LoginScreen` — phone number (+57, 10 digits)
2. `PinScreen` — 6-digit PIN via `NumPad`
3. `OtpLoginScreen` — 6-digit OTP sent via WhatsApp (60 s resend)

### Register (4 steps + OTP)
1. Account type: `persona` (natural person) | `empresa` (company)
2. Contact info — persona: name, email, phone | empresa: razón social, NIT, email, phone
3. Identity — persona: document type+number | empresa: legal representative info
4. Password (8–64 chars, real-time strength bar)
5. Phone OTP verification

### Backend endpoints (stubbed — connect when API is ready)

| Endpoint | Called from |
|---|---|
| `POST /auth/login` | `PinScreen._submit()` |
| `POST /auth/login/verify-otp` | `OtpLoginScreen._verify()` |
| `POST /auth/register` | `RegisterScreen._next()` (step 3→4) |
| `POST /auth/register/verify-phone` | `_OtpRegisterScreen._verify()` |
| `POST /auth/refresh` | future interceptor |
| `POST /auth/logout` | client-side (discard tokens) |

> Token storage: use `flutter_secure_storage` — never `SharedPreferences` in plain text.
> All API calls are marked with `// TODO` comments in the presentation files.

---

## Conventions

### Riverpod providers

Always use code generation:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'my_provider.g.dart';

@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  MyState build() => MyState.initial();
}
```

- `ConsumerWidget` for stateless widgets that read providers
- `ConsumerStatefulWidget` when local widget state is also needed
- Never use `setState` — delegate state to Riverpod

### Adding a new feature

1. Create `lib/features/<name>/presentation/<name>_screen.dart`
2. Add route in `lib/app/router.dart`
3. Create providers with `@riverpod`, run `build_runner build`
4. Add data layer in `lib/features/<name>/data/` if needed

### Theme

The app is **dark-only**. `AppTheme.dark` is set for both `theme` and `darkTheme` in `app.dart`. Do not add light theme variants or theme toggle UI.

---

## Files to never edit

- `*.g.dart` — generated by build_runner
- `ios/`, `android/`, `macos/` platform folders — modify only via Flutter CLI or platform-specific config

---

## Testing

- Unit tests: mirror `lib/` structure under `test/`
- Widget tests: wrap with `ProviderScope` and override providers as needed
- Integration tests: `integration_test/` with `flutter_test` driver

```dart
// Widget test example
await tester.pumpWidget(
  ProviderScope(
    overrides: [myProvider.overrideWith(() => FakeNotifier())],
    child: const App(),
  ),
);
```

---

## Branch strategy

| Branch | Purpose |
|---|---|
| `main` | Stable / production |
| `staging` | Pre-production validation |
| `dev` | Feature integration base |
| `feat/*` | Active feature branches |

Flow: `feat/*` → PR → `dev` → PR → `staging` → PR → `main`.
