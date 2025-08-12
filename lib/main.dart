import 'package:flutter/material.dart';
import 'home_page.dart'; // Importamos nuestro archivo de la pantalla principal

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Esto quita la cinta roja de "DEBUG" de la esquina.
      debugShowCheckedModeBanner: false,
      title: 'Control ESP32',
      theme: ThemeData(
        // Definimos el estilo de la barra superior para toda la app
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[700], // Un azul oscuro
          foregroundColor: Colors.white, // Color para el título y los iconos
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Nos aseguramos de que la pantalla de inicio sea nuestra HomePage
      home: const HomePage(),
    );
  }
}