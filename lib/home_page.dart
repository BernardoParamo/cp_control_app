import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'control_page.dart';
import 'dart:developer' as developer; // Import para logging

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    developer.log('HomePage: initState - Iniciando búsqueda automática.', name: 'APP.LIFECYCLE');
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    developer.log('HomePage: Pidiendo permisos...', name: 'APP.BLUETOOTH');
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var locationStatus = await Permission.location.request();
    
    developer.log('HomePage: Permisos - Scan: ${bluetoothScanStatus.name}, Connect: ${bluetoothConnectStatus.name}, Location: ${locationStatus.name}', name: 'APP.BLUETOOTH');

    if (bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted && locationStatus.isGranted) {
      developer.log('HomePage: Permisos concedidos. Iniciando escaneo...', name: 'APP.BLUETOOTH');
      setState(() {
        _isDiscovering = true;
        _devicesList = [];
      });

      _bluetooth.startDiscovery().listen((r) {
        developer.log('HomePage: Dispositivo encontrado - ${r.device.name ?? "SIN NOMBRE"} (${r.device.address})', name: 'APP.BLUETOOTH.SCAN');
        final existingIndex = _devicesList.indexWhere((device) => device.address == r.device.address);
        if (existingIndex < 0 && r.device.name != null && r.device.name!.isNotEmpty) {
          _devicesList.add(r.device);
          setState(() {});
        }
      }).onDone(() {
        developer.log('HomePage: Escaneo finalizado.', name: 'APP.BLUETOOTH.SCAN');
        setState(() {
          _isDiscovering = false;
        });
      });
    } else {
      developer.log('HomePage: Uno o más permisos fueron denegados.', name: 'APP.ERROR');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesitan permisos de Bluetooth y ubicación.'))
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    developer.log('HomePage: Intentando conectar a ${device.name}...', name: 'APP.BLUETOOTH');
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
      developer.log('HomePage: ¡CONECTADO con éxito!', name: 'APP.BLUETOOTH');
      
      if (mounted) {
        Navigator.of(context).pop(); // Cierra el diálogo
        developer.log('HomePage: Navegando a ControlPage...', name: 'APP.NAVIGATION');
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ControlPage(connection: connection)),
        );
        developer.log('HomePage: Vuelto de ControlPage. Reiniciando búsqueda.', name: 'APP.NAVIGATION');
      }
      
      // Al volver, reiniciamos la búsqueda para estar listos por si el dispositivo se reinició
      if(mounted) _startDiscovery();

    } catch (e) {
      developer.log('HomePage: Fallo al conectar.', name: 'APP.ERROR', error: e.toString());
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Dispositivo de Control'),
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop_circle : Icons.search),
            tooltip: 'Buscar de nuevo',
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
                if (device.name == 'CP_CONTROL') {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth_drive, color: Colors.blue, size: 36),
                      title: Text(device.name!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(device.address),
                      onTap: () => _connectToDevice(device),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
