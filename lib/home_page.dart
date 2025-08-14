import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'control_page.dart';
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    developer.log('HomePage: Pidiendo permisos...', name: 'APP.BLUETOOTH');
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request(); // Necesario para getBondedDevices

    if (bluetoothConnectStatus.isGranted && bluetoothScanStatus.isGranted) {
      developer.log('HomePage: Permiso concedido. Obteniendo dispositivos vinculados...', name: 'APP.BLUETOOTH');
      if(mounted) setState(() { _isLoading = true; _devicesList = []; });

      try {
        List<BluetoothDevice> pairedDevices = await _bluetooth.getBondedDevices();
        if(mounted) setState(() { _devicesList = pairedDevices; });
        developer.log('HomePage: Encontrados ${_devicesList.length} dispositivos vinculados.', name: 'APP.BLUETOOTH');
      } catch (e) {
        developer.log('HomePage: Error al obtener dispositivos.', name: 'APP.ERROR', error: e.toString());
      } finally {
        if(mounted) setState(() { _isLoading = false; });
      }

    } else {
      developer.log('HomePage: Permisos de Bluetooth denegados.', name: 'APP.ERROR');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesitan permisos de Bluetooth.'))
        );
      }
    }
  }

  // --- ESTA ES LA FUNCIÓN QUE HEMOS RELLENADO ---
  Future<void> _connectToDevice(BluetoothDevice device) async {
    developer.log('HomePage: Intentando conectar a ${device.name}...', name: 'APP.BLUETOOTH');
    if (!mounted) return;

    // Muestra un diálogo de "Conectando..."
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AlertDialog(
        title: Text("Conectando..."),
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Por favor, espere."),],),
      ),
    );

    try {
      // Intenta establecer la conexión
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      developer.log('HomePage: ¡CONECTADO con éxito!', name: 'APP.BLUETOOTH');
      
      if (mounted) {
        Navigator.of(context).pop(); // Cierra el diálogo de "Conectando..."
        developer.log('HomePage: Navegando a ControlPage...', name: 'APP.NAVIGATION');
        
        // Navega a la pantalla de control, pasándole la conexión activa
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ControlPage(connection: connection)),
        );
        
        // Cuando se vuelve de ControlPage (ej. al desconectar), refrescamos la lista
        developer.log('HomePage: Vuelto de ControlPage. Refrescando lista.', name: 'APP.NAVIGATION');
        _getPairedDevices();
      }

    } catch (e) {
      developer.log('HomePage: Fallo al conectar.', name: 'APP.ERROR', error: e.toString());
      if (mounted) Navigator.of(context).pop(); // Cierra el diálogo de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar: ${e.toString()}')));
      }
    }
  }
  // --- FIN DE LA FUNCIÓN RELLENADA ---

  @override
  Widget build(BuildContext context) {
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