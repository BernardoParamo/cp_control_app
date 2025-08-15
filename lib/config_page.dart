import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ConfigPage extends StatefulWidget {
  final BluetoothConnection connection;
  final StreamSubscription<Uint8List>? dataSubscription;

  const ConfigPage({
    super.key,
    required this.connection,
    required this.dataSubscription,
  });

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  bool _isLoading = true;
  Map<String, dynamic> _configData = {};
  String _dataBuffer = '';
  final Map<String, TextEditingController> _controllers = {};
  bool _btEnabled = true;
  bool _serialEnabled = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _reconfigureAndResumeSubscription();
    _requestConfig();
  }

  @override
  void dispose() {
    widget.dataSubscription?.pause();
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _sendCommand(String command) {
    if (widget.connection.isConnected) {
      widget.connection.output.add(utf8.encode("<$command>"));
      widget.connection.output.allSent;
      developer.log("Enviado comando: $command", name: "APP.COMMAND");
    }
  }

  void _reconfigureAndResumeSubscription() {
    widget.dataSubscription?.onData((data) {
      _dataBuffer += utf8.decode(data, allowMalformed: true);
      while (_dataBuffer.contains('\n')) {
        final endIndex = _dataBuffer.indexOf('\n');
        final message = _dataBuffer.substring(0, endIndex).trim();
        _dataBuffer = _dataBuffer.substring(endIndex + 1);
        if (message.startsWith('{') && message.endsWith('}')) {
          try {
            final jsonData = jsonDecode(message);
            if (jsonData['type'] == 'config') {
              _updateConfigUI(jsonData);
            } else if (jsonData['type'] == 'wifi_scan') {
              List<String> networks = List<String>.from(jsonData['networks']);
              _showWifiNetworksDialog(networks);
            }
          } catch (e) {
            developer.log('Error al decodificar JSON: $e', name: 'Bluetooth.JSON');
          }
        }
      }
    });
    widget.dataSubscription?.resume();
  }

  void _requestConfig() {
    setState(() { _isLoading = true; });
    _sendCommand('get_config');
  }

  void _updateConfigUI(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _configData = data;
        _btEnabled = _configData['bt_enabled'] ?? true;
        _serialEnabled = _configData['serial_enabled'] ?? true;
        _initializeControllers();
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    _controllers.forEach((key, controller) => controller.dispose());
    _controllers.clear();
    _configData.forEach((key, value) {
      if (value is String) {
        _controllers[key] = TextEditingController(text: value);
      } else if (value is num) {
        _controllers[key] = TextEditingController(text: value.toString());
      }
    });
    List<String> listKeys = ['inputNames', 'outputNames', 'pulseTimes'];
    for (var key in listKeys) {
      if (_configData.containsKey(key) && _configData[key] is List) {
        for (int i = 0; i < (_configData[key] as List).length; i++) {
          _controllers['${key}_$i'] = TextEditingController(text: _configData[key][i].toString());
        }
      }
    }
  }

  void _confirmAndSaveConfig() {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Cambios"),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Se enviará la nueva configuración al dispositivo."),
                SizedBox(height: 10),
                Text("El dispositivo se reiniciará y la conexión se perderá."),
                SizedBox(height: 10),
                Text("¿Desea continuar?"),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () { Navigator.of(context).pop(); },
            ),
            ElevatedButton(
              child: const Text('Guardar y Reiniciar'),
              onPressed: () {
                _executeSave();
                Navigator.of(context).pop();
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) { Navigator.of(context).pop(); }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dispositivo reiniciando. Por favor, vuelva a conectar.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _executeSave() {
    developer.log("Construyendo JSON de configuración para enviar...", name: "APP.COMMAND");
    
    Map<String, dynamic> configToSend = {
      'ip': _controllers['ip']?.text ?? "",
      'subnet': _controllers['subnet']?.text ?? "",
      'gateway': _controllers['gateway']?.text ?? "",
      'wifi_ssid': _controllers['wifi_ssid']?.text ?? "",
      'wifi_password': _controllers['wifi_password']?.text ?? "",
      'bt_device_name': _controllers['bt_device_name']?.text ?? "",
      'bt_enabled': _btEnabled,
      'serial_enabled': _serialEnabled,
      'serial_baud_rate': int.tryParse(_controllers['serial_baud_rate']?.text ?? '0'),
      'globalPulseTime': int.tryParse(_controllers['globalPulseTime']?.text ?? '0'),
      'inputNames': List.generate(8, (i) => _controllers['inputNames_$i']?.text ?? ""),
      'outputNames': List.generate(4, (i) => _controllers['outputNames_$i']?.text ?? ""),
      'pulseTimes': List.generate(4, (i) => int.tryParse(_controllers['pulseTimes_$i']?.text ?? '0')),
      'serial_cmd_status': _controllers['serial_cmd_status']?.text,
      'serial_cmd_turn_on': _controllers['serial_cmd_turn_on']?.text,
      'serial_cmd_turn_off': _controllers['serial_cmd_turn_off']?.text,
      'serial_cmd_pulse': _controllers['serial_cmd_pulse']?.text,
      'serial_cmd_help': _controllers['serial_cmd_help']?.text,
    };

    String jsonString = jsonEncode(configToSend);
    _sendCommand('set_config $jsonString');
    _sendCommand('save_and_reboot');
  }

  void _scanWifi() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando redes WiFi...')));
    _sendCommand('scan_wifi');
  }

  void _showWifiNetworksDialog(List<String> networks) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Redes WiFi Encontradas"),
          content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: networks.length, itemBuilder: (context, index) {
            return ListTile(title: Text(networks[index]), onTap: () {
              _controllers['wifi_ssid']?.text = networks[index];
              Navigator.of(context).pop();
            });
          })),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar"))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: Theme.of(context).primaryColorDark,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.router), text: 'Red'),
                  Tab(icon: Icon(Icons.input), text: 'Nombres E/S'),
                  Tab(icon: Icon(Icons.timer), text: 'Tiempos'),
                  Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
                  Tab(icon: Icon(Icons.terminal), text: 'Serial'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildNetworkTab(),
                  _buildNamesTab(),
                  _buildTimesTab(),
                  _buildBluetoothTab(),
                  _buildSerialTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _confirmAndSaveConfig,
          icon: const Icon(Icons.save),
          label: const Text("Guardar Cambios"),
        ),
      ),
    );
  }
  
  Widget _buildTextField(String key, String label, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildNetworkTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("Configuración Ethernet", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      _buildTextField('ip', 'Dirección IP'),
      _buildTextField('subnet', 'Máscara de Subred'),
      _buildTextField('gateway', 'Puerta de Enlace'),
      const Divider(height: 40),
      Text("Configuración WiFi", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Row(children: [ Expanded(child: _buildTextField('wifi_ssid', 'Nombre de Red (SSID)')), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.search), onPressed: _scanWifi, tooltip: 'Buscar Redes')]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextFormField(
          controller: _controllers['wifi_password'],
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Contraseña WiFi', border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () { setState(() { _isPasswordVisible = !_isPasswordVisible; }); },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNamesTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("Nombres de Entradas", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      ...List.generate((_configData['inputNames'] as List?)?.length ?? 0, (i) => _buildTextField('inputNames_$i', 'Entrada ${i + 1}')),
      const Divider(height: 40),
      Text("Nombres de Salidas", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      ...List.generate((_configData['outputNames'] as List?)?.length ?? 0, (i) => _buildTextField('outputNames_$i', 'Salida ${i + 1}')),
    ]);
  }

  Widget _buildTimesTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("Tiempos de Pulso (ms)", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      ...List.generate((_configData['outputNames'] as List?)?.length ?? 0, (i) => _buildTextField('pulseTimes_$i', 'Pulso Salida ${i + 1} (${_configData['outputNames']?[i] ?? ''})', keyboardType: TextInputType.number)),
      const Divider(height: 40),
      _buildTextField('globalPulseTime', 'Pulso a Todas (ms)', keyboardType: TextInputType.number),
    ]);
  }
  
  Widget _buildBluetoothTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
        Text("Configuración de Bluetooth", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        SwitchListTile(title: const Text("Habilitar Bluetooth"), value: _btEnabled, onChanged: (bool value) { setState(() { _btEnabled = value; }); }),
        _buildTextField('bt_device_name', 'Nombre del Dispositivo'),
    ]);
  }
  
  Widget _buildSerialTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("Configuración del Puerto Serie", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      SwitchListTile(
        title: const Text("Habilitar control por puerto serie"),
        value: _serialEnabled,
        onChanged: (bool value) {
            setState(() { _serialEnabled = value; });
        },
      ),
      const SizedBox(height: 10),
      _buildTextField('serial_baud_rate', 'Velocidad (Baud Rate)', keyboardType: TextInputType.number),
      const Divider(height: 40),
      Text("Comandos Personalizados", style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      _buildTextField('serial_cmd_status', 'Comando de Estado'),
      _buildTextField('serial_cmd_turn_on', 'Comando para Encender'),
      _buildTextField('serial_cmd_turn_off', 'Comando para Apagar'),
      _buildTextField('serial_cmd_pulse', 'Comando de Pulso'),
      _buildTextField('serial_cmd_help', 'Comando de Ayuda'),
    ]);
  }
}