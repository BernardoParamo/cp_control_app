// lib/bluetooth_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  // --- Singleton: Asegura una única instancia del servicio en la app ---
  BluetoothService._privateConstructor();
  static final BluetoothService instance = BluetoothService._privateConstructor();

  // --- Propiedades de estado ---
  BluetoothConnection? _connection;
  BluetoothDevice? _device;
  
  // Flags para manejar procesos especiales y evitar comportamientos indeseados
  bool _isConnecting = false;
  bool _isScanningWifi = false;
  bool _isRebooting = false; 

  // Streams para que las pantallas se suscriban y reaccionen a los cambios
  final StreamController<String> _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // --- Getters públicos ---
  bool get isConnected => _connection?.isConnected ?? false;
  String _dataBuffer = '';

  // --- Métodos de Conexión ---
  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;
    _device = device;
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectionStatusController.add(true);
      developer.log('Servicio: Conectado a ${device.name}', name: 'APP.BLUETOOTH');
      
      _connection!.input!.listen(
        _onDataReceived,
        onDone: _onDisconnected,
        onError: (error) {
          developer.log('Servicio: Error en la conexión', name: 'APP.ERROR', error: error);
          _onDisconnected();
        }
      );
    } catch (e) {
      developer.log('Servicio: Fallo al conectar.', name: 'APP.ERROR', error: e.toString());
      _connectionStatusController.add(false);
    } finally {
      _isConnecting = false;
    }
  }

  void _onDataReceived(Uint8List data) {
    _dataBuffer += utf8.decode(data, allowMalformed: true);
    while (_dataBuffer.contains('\n')) {
      final endIndex = _dataBuffer.indexOf('\n');
      final message = _dataBuffer.substring(0, endIndex).trim();
      _dataBuffer = _dataBuffer.substring(endIndex + 1);
      if (message.isNotEmpty) {
        _dataStreamController.add(message);
      }
    }
  }

  void _onDisconnected() {
    developer.log('Servicio: Desconexión detectada.', name: 'APP.BLUETOOTH');
    _connection?.dispose();
    _connection = null;
    
    if (_isScanningWifi) {
      developer.log('Servicio: Desconexión por escaneo WiFi. Iniciando reconexión...', name: 'APP.BLUETOOTH');
      _isScanningWifi = false;
      _attemptReconnect();
    } else if (_isRebooting) {
      developer.log('Servicio: Desconexión por reinicio. No se reconectará automáticamente.', name: 'APP.BLUETOOTH');
      _isRebooting = false; // Reseteamos la bandera
      _connectionStatusController.add(false); // Notificamos a las pantallas que la conexión terminó
    } else {
      // Desconexión inesperada
      _connectionStatusController.add(false);
    }
  }

  void _attemptReconnect() {
    if (_device == null) return;
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (isConnected) {
        timer.cancel();
        return;
      }
      try {
        await connect(_device!);
        if (isConnected) {
          developer.log('Servicio: ¡Reconexión exitosa!', name: 'APP.BLUETOOTH');
          timer.cancel();
          sendCommand('get_scan_results');
        }
      } catch (e) {
        // Silenciamos los errores para no spamear la consola durante los reintentos
      }
      if (timer.tick > 10) { 
        developer.log('Servicio: No se pudo reconectar tras 10 intentos.', name: 'APP.ERROR');
        timer.cancel();
        _connectionStatusController.add(false);
      }
    });
  }

  // --- Métodos para enviar comandos ---
  void sendCommand(String command) {
    if (isConnected) {
      developer.log("Enviando comando: $command", name: "APP.COMMAND");
      _connection!.output.add(utf8.encode("<$command>"));
      _connection!.output.allSent;
    }
  }

  void startWifiScan() {
    if (!isConnected) return;
    _isScanningWifi = true;
    sendCommand('scan_wifi');
  }

  // --- MÉTODOS SEPARADOS PARA EL FLUJO DE GUARDADO ---
  void sendConfig(Map<String, dynamic> config) {
    if (!isConnected) return;
    String jsonString = jsonEncode(config);
    sendCommand('set_config $jsonString');
  }

  void sendRebootCommand() {
    if (!isConnected) return;
    _isRebooting = true; // Activamos la bandera ANTES de enviar el comando de reinicio
    sendCommand('save_and_reboot');
  }
}