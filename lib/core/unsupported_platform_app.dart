import 'package:flutter/material.dart';

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'This application supports only macOS and Windows desktop.',
          ),
        ),
      ),
    );
  }
}
