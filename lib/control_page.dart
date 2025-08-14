import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'config_page.dart'; // Mantener comentado hasta que creemos esa pantalla

class ControlPage extends StatefulWidget {
  final BluetoothConnection connection;
  const ControlPage({super.key, required this.connection});
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  List<Map<String, dynamic>> inputs = [];
  List<Map<String, dynamic>> outputs = [];
  bool isLoading = true;

  StreamSubscription<Uint8List>? _dataSubscription;
  String _dataBuffer = '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
    
    // --- AÑADIR ESTE BLOQUE DE CÓDIGO ---
    // Inicia un timer que se ejecuta cada segundo para pedir el estado.
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.connection.isConnected) {
        _getStatus();
      } else {
        // Si la conexión se pierde, cancelamos el timer.
        timer.cancel();
      }
    });
    // --- FIN DEL BLOQUE AÑADIDO ---
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _pollingTimer?.cancel(); // <-- AÑADIR ESTA LÍNEA
    super.dispose();
  }

  void _startListening() {
    _dataSubscription = widget.connection.input?.listen(
      (data) {
        _dataBuffer += utf8.decode(data, allowMalformed: true);
        while (_dataBuffer.contains('\n')) {
          final endIndex = _dataBuffer.indexOf('\n');
          final message = _dataBuffer.substring(0, endIndex).trim();
          _dataBuffer = _dataBuffer.substring(endIndex + 1);

          if (message.startsWith('{') && message.endsWith('}')) {
            try {
              final jsonData = jsonDecode(message);
              _updateStatus(jsonData);
            } catch (e) {
              developer.log('Error al decodificar JSON: $e', name: 'Bluetooth.JSON', error: 'Datos: $message');
            }
          }
        }
      },
      onDone: () {
        developer.log('Conexión perdida.', name: 'Bluetooth');
        if (mounted) Navigator.of(context).pop();
      },
      onError: (error) {
        developer.log('Error en la conexión', name: 'Bluetooth', error: error);
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  void _updateStatus(Map<String, dynamic> data) {
    if (data.containsKey('inputs') && data.containsKey('outputs')) {
      if (mounted) {
        setState(() {
          inputs = List<Map<String, dynamic>>.from(data['inputs']);
          outputs = List<Map<String, dynamic>>.from(data['outputs']);
          isLoading = false;
        });
      }
    }
  }

  void _sendCommand(String command) {
    if (widget.connection.isConnected) {
      widget.connection.output.add(utf8.encode("<$command>"));
      widget.connection.output.allSent;
    }
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Estado',
            onPressed: isLoading ? null : _getStatus,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () {
              // Lógica para navegar a la página de configuración
              // (La implementaremos en el siguiente paso)
            },
          ),
        ],
      ),
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
                    _buildActionButton(
                      label: 'ON',
                      icon: Icons.power_settings_new,
                      color: Colors.green,
                      onPressed: () => _sendCommand('on $outputNum'),
                    ),
                    _buildActionButton(
                      label: 'OFF',
                      icon: Icons.power_off,
                      color: Colors.red,
                      onPressed: () => _sendCommand('off $outputNum'),
                    ),
                    _buildActionButton(
                      label: 'PULSO',
                      icon: Icons.touch_app,
                      color: Colors.blueAccent,
                      onPressed: () => _sendCommand('pulse $outputNum'),
                    ),
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}