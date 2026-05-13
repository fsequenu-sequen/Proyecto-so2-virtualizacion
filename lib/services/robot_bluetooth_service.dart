import 'dart:async';

import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:permission_handler/permission_handler.dart';

class RobotBluetoothService {
  final FlutterBluetoothClassic _bluetooth = FlutterBluetoothClassic();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  final StreamController<String> _receivedController =
      StreamController<String>.broadcast();

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothData>? _dataSubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;

  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get receivedStream => _receivedController.stream;

  Future<bool> initialize() async {
    try {
      final permissionsOk = await _requestPermissions();

      if (!permissionsOk) {
        _statusController.add('Permisos de Bluetooth no concedidos');
        return false;
      }

      final supported = await _bluetooth.isBluetoothSupported();
      if (!supported) {
        _statusController.add('Este dispositivo no soporta Bluetooth');
        return false;
      }

      final enabled = await _bluetooth.isBluetoothEnabled();
      if (!enabled) {
        _statusController.add('Bluetooth está apagado. Actívalo en el teléfono.');
        return false;
      }

      _listenEvents();

      _statusController.add('Bluetooth listo');
      return true;
    } catch (e) {
      _statusController.add('Error al iniciar Bluetooth: $e');
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    final bluetoothScan = statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final bluetoothConnect =
        statuses[Permission.bluetoothConnect]?.isGranted ?? true;

    final location =
        statuses[Permission.locationWhenInUse]?.isGranted ?? true;

    return bluetoothScan && bluetoothConnect && location;
  }

  void _listenEvents() {
    _stateSubscription ??= _bluetooth.onStateChanged.listen((state) {
      if (state.isEnabled) {
        _statusController.add('Bluetooth encendido');
      } else {
        _statusController.add('Bluetooth apagado');
        _isConnected = false;
        _connectedDevice = null;
      }
    });

    _connectionSubscription ??=
        _bluetooth.onConnectionChanged.listen((connectionState) {
      _isConnected = connectionState.isConnected;

      if (_isConnected) {
        _statusController.add('Robot conectado por Bluetooth');
      } else {
        _connectedDevice = null;
        _statusController.add('Robot desconectado');
      }
    });

    _dataSubscription ??= _bluetooth.onDataReceived.listen((data) {
      final text = data.asString();
      _receivedController.add(text);
    });
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getPairedDevices();
    } catch (e) {
      _statusController.add('Error al obtener dispositivos emparejados: $e');
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      _statusController.add('Conectando a ${device.name}...');

      final connected = await _bluetooth.connect(device.address);

      if (connected) {
        _isConnected = true;
        _connectedDevice = device;
        _statusController.add('Conectado a ${device.name}');
      } else {
        _statusController.add('No se pudo conectar a ${device.name}');
      }

      return connected;
    } catch (e) {
      _statusController.add('Error de conexión: $e');
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final result = await _bluetooth.disconnect();
      _isConnected = false;
      _connectedDevice = null;
      _statusController.add('Desconectado del robot');
      return result;
    } catch (e) {
      _statusController.add('Error al desconectar: $e');
      return false;
    }
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected) {
      _statusController.add('No hay conexión Bluetooth con el robot');
      return false;
    }

    try {
      final cleanCommand = command.trim();

      if (cleanCommand.isEmpty) {
        return false;
      }

      final commandToSend = '$cleanCommand\n';

      final sent = await _bluetooth.sendString(commandToSend);

      if (sent) {
        _statusController.add('Enviado: $cleanCommand');
      } else {
        _statusController.add('No se pudo enviar: $cleanCommand');
      }

      return sent;
    } catch (e) {
      _statusController.add('Error enviando comando: $e');
      return false;
    }
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _statusController.close();
    _receivedController.close();
  }
}