import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest.xml', () {
    test('debe contener el permiso INTERNET', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');

      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'El archivo AndroidManifest.xml debe existir',
      );

      final content = manifestFile.readAsStringSync();
      final hasInternetPermission = content.contains(
        'android:name="android.permission.INTERNET"',
      );

      expect(
        hasInternetPermission,
        isTrue,
        reason: 'AndroidManifest.xml debe declarar '
            '<uses-permission android:name="android.permission.INTERNET"/>',
      );
    });
  });
}
