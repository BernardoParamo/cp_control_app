// lib/control_page.dart

import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'bluetooth_service.dart'; // <-- IMPORTANTE
import 'config_page.dart'; 

class ControlPage extends StatefulWidget {
  // Ya no recibe 'connection' en el constructor
  const ControlPage({super.key});
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final BluetoothService _bluetoothService = BluetoothService.instance; // <-- Usar la instancia del servicio
  late StreamSubscription<String> _dataSubscription;
  late StreamSubscription<bool> _connectionSubscription;

  List<Map<String, dynamic>> inputs = [];
  List<Map<String, dynamic>> outputs = [];
  bool isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_bluetoothService.isConnected) {
        _getStatus();
      }
    });
    
    // Escuchar cambios en el estado de la conexión
    _connectionSubscription = _bluetoothService.connectionStatusStream.listen((isConnected) {
      if (!isConnected && mounted) {
        developer.log('ControlPage: detectó desconexión. Volviendo atrás.', name: 'APP.NAVIGATION');
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription.cancel();
    _connectionSubscription.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startListening() {
    _dataSubscription = _bluetoothService.dataStream.listen((message) {
      if (message.startsWith('{') && message.endsWith('}')) {
        try {
          final jsonData = jsonDecode(message);
          if (jsonData['type'] == 'status') {
             _updateStatus(jsonData);
          }
        } catch (e) {
          developer.log('Error al decodificar JSON: $e', name: 'Bluetooth.JSON', error: 'Datos: $message');
        }
      }
    });
  }

  void _updateStatus(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        inputs = List<Map<String, dynamic>>.from(data['inputs']);
        outputs = List<Map<String, dynamic>>.from(data['outputs']);
        isLoading = false;
      });
    }
  }

  void _sendCommand(String command) {
    _bluetoothService.sendCommand(command);
  }
  
  void _getStatus() {
     _sendCommand('get_status_json');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () {
              // Navegar es más simple ahora
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ConfigPage()),
              );
            },
          ),
        ],
      ),
      // El resto del widget build no necesita cambios.
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Esperando estado del dispositivo..."),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _getStatus(),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionTitle('Salidas'),
                  _buildOutputsList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Entradas'),
                  _buildInputsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOutputsList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: outputs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final output = outputs[index];
        final outputNum = index + 1;
        final bool isOutputOn = output['state'] == 1;
        final String outputName = output['name'] as String? ?? 'Salida $outputNum';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOutputOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                      color: isOutputOn ? Colors.amber.shade700 : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        outputName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(label: 'ON', icon: Icons.power_settings_new, color: Colors.green, onPressed: () => _sendCommand('on $outputNum')),
                    _buildActionButton(label: 'OFF', icon: Icons.power_off, color: Colors.red, onPressed: () => _sendCommand('off $outputNum')),
                    _buildActionButton(label: 'PULSO', icon: Icons.touch_app, color: Colors.blueAccent, onPressed: () => _sendCommand('pulse $outputNum')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputsList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: List.generate(inputs.length, (index) {
          final input = inputs[index];
          return ListTile(
            title: Text(input['name'] as String? ?? 'Entrada ${index + 1}'),
            trailing: Icon(
              input['state'] == 1 ? Icons.circle : Icons.circle_outlined,
              color: input['state'] == 1 ? Colors.green.shade600 : Colors.grey,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}