import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ConfigPage extends StatefulWidget {
  final BluetoothConnection connection;

  const ConfigPage({super.key, required this.connection});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración (En construcción)'),
      ),
      body: const Center(
        child: Text('Esta pantalla permitirá configurar el dispositivo.'),
      ),
    );
  }
}