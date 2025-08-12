import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import 'control_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  List<BluetoothDevice> _devicesList = [];
  bool _isDiscovering = false;

  Future<void> _startDiscovery() async {
    // Primero, pedimos los permisos necesarios
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var locationStatus = await Permission.location.request();

    if (bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted && locationStatus.isGranted) {
      // Si tenemos permisos, iniciamos el escaneo
      setState(() {
        _isDiscovering = true;
        _devicesList = [];
      });

      _bluetooth.startDiscovery().listen((r) {
        final existingIndex = _devicesList.indexWhere((device) => device.address == r.device.address);
        if (existingIndex < 0 && r.device.name != null && r.device.name!.isNotEmpty) {
          _devicesList.add(r.device);
          setState(() {});
        }
      }).onDone(() {
        setState(() {
          _isDiscovering = false;
        });
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesitan permisos de Bluetooth y ubicación.'))
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await _bluetooth.cancelDiscovery();
    setState(() { _isDiscovering = false; });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AlertDialog(
        title: Text("Conectando..."),
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Por favor, espere."),],),
      ),
    );

    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      if (mounted) {
        Navigator.of(context).pop(); // Cierra el diálogo
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ControlPage(connection: connection)),
        );
      }
      if (mounted) setState(() { _devicesList = []; });
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      print('No se pudo conectar al dispositivo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Dispositivos'),
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.bluetooth_searching),
            onPressed: () {
              if (_isDiscovering) {
                _bluetooth.cancelDiscovery();
              } else {
                _startDiscovery();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDiscovering) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _devicesList[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.name ?? 'Dispositivo sin nombre'),
                  subtitle: Text(device.address),
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}