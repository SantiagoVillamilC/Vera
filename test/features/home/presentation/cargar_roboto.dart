import 'dart:io';

import 'package:flutter/services.dart';

/// La fuente por defecto de las pruebas (Ahem) mide cada letra como un
/// cuadrado, lo que provoca desbordes que no existen en el dispositivo. Para
/// medir el layout real se carga Roboto desde el SDK de Flutter.
Future<void> cargarRoboto() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final dir = '$raiz/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final peso in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('$dir/Roboto-$peso.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
