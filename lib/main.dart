import 'package:flutter/material.dart';
import 'welcome_page.dart'; // <-- CAMBIO: Importamos la nueva pantalla

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control ESP32',
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromRGBO(9, 114, 61, 1),
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(139, 193, 64, 1)),
        useMaterial3: true,
      ),
      // --- CAMBIO: La app ahora empieza en la WelcomePage ---
      home: const WelcomePage(),
    );
  }
}