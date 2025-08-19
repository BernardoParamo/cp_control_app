// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'control_page.dart';
import 'bluetooth_service.dart'; // <-- IMPORTANTE: Importar el servicio
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  final BluetoothService _bluetoothService = BluetoothService.instance; // <-- Usar la instancia del servicio
  List<BluetoothDevice> _devicesList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    // El resto de esta función está bien, no necesita cambios.
    developer.log('HomePage: Pidiendo permisos...', name: 'APP.BLUETOOTH');
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request();

    if (bluetoothConnectStatus.isGranted && bluetoothScanStatus.isGranted) {
      if(mounted) setState(() { _isLoading = true; _devicesList = []; });
      try {
        List<BluetoothDevice> pairedDevices = await _bluetooth.getBondedDevices();
        if(mounted) setState(() { _devicesList = pairedDevices; });
      } catch (e) {
        developer.log('Error al obtener dispositivos', name: 'APP.ERROR', error: e);
      } finally {
        if(mounted) setState(() { _isLoading = false; });
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se necesitan permisos de Bluetooth.')));
    }
  }
  
  // --- FUNCIÓN DE CONEXIÓN MODIFICADA ---
  Future<void> _connectToDevice(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AlertDialog(
        title: Text("Conectando..."),
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Por favor, espere."),],),
      ),
    );
    
    // Delegamos la conexión al servicio
    await _bluetoothService.connect(device);

    if (mounted) Navigator.of(context).pop(); // Cierra el diálogo

    if (_bluetoothService.isConnected) {
      // Si la conexión fue exitosa, navegamos a la página de control
      if(mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ControlPage()),
        );
        // Cuando se vuelva, refrescamos la lista
        _getPairedDevices();
      }
    } else {
      // Si falló, mostramos un error
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al conectar con el dispositivo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // El widget build no necesita cambios.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Dispositivo'),
        actions: [
          IconButton(
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Icon(Icons.refresh),
            tooltip: 'Refrescar Lista',
            onPressed: _isLoading ? null : _getPairedDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _devicesList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.developer_board, color: Color.fromRGBO(139, 193, 64, 1), size: 36),
                    title: Text(device.name ?? "Dispositivo sin nombre", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(device.address),
                    onTap: () => _connectToDevice(device),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}