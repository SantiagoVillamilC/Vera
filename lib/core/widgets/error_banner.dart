import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialBanner(
        content: Text(message),
        actions: const <Widget>[],
      );
}
