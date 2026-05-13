import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

import '../services/event_log_service.dart';

class ManualBluetoothScreen extends StatefulWidget {
  const ManualBluetoothScreen({super.key});

  @override
  State<ManualBluetoothScreen> createState() => _ManualBluetoothScreenState();
}

class _ManualBluetoothScreenState extends State<ManualBluetoothScreen>
    with WidgetsBindingObserver {
  late final FlutterBluetoothClassic _bluetooth;

  final TextEditingController _customCommandController = TextEditingController();

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothData>? _dataSubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;

  List<BluetoothDevice> _dispositivosEmparejados = [];
  BluetoothDevice? _dispositivoSeleccionado;
  BluetoothDevice? _dispositivoConectado;

  BluetoothConnectionState? _connectionState;

  bool _bluetoothDisponible = false;
  bool _bluetoothEncendido = false;
  bool _conectado = false;
  bool _probandoConexion = false;
  bool _cargandoDispositivos = false;
  bool _enviando = false;

  int _ultimoEnvioMs = 0;

  String _estado = 'Listo. Selecciona el ESP32S emparejado y conecta por Bluetooth.';
  String _ultimoComando = 'Ninguno';
  String _respuestaBluetooth = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bluetooth = FlutterBluetoothClassic();
    _iniciarBluetooth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _customCommandController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _verificarEstadoBluetooth();
    }
  }

  Future<void> _iniciarBluetooth() async {
    _escucharEventosBluetooth();
    await _verificarEstadoBluetooth();
  }

  void _escucharEventosBluetooth() {
    _stateSubscription ??= _bluetooth.onStateChanged.listen(
      (BluetoothState state) async {
        if (!mounted) return;

        setState(() {
          _bluetoothEncendido = state.isEnabled;
          if (!state.isEnabled) {
            _conectado = false;
            _dispositivoConectado = null;
            _estado = 'Bluetooth está apagado. Actívalo en el teléfono.';
          } else {
            _estado = 'Bluetooth encendido. Puedes buscar el ESP32S.';
          }
        });

        if (state.isEnabled) {
          await _cargarDispositivosEmparejados();
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _estado = 'Error escuchando Bluetooth: $error';
        });
      },
    );

    _connectionSubscription ??= _bluetooth.onConnectionChanged.listen(
      (BluetoothConnectionState state) {
        if (!mounted) return;

        BluetoothDevice? encontrado;

        for (final BluetoothDevice device in _dispositivosEmparejados) {
          if (device.address == state.deviceAddress) {
            encontrado = device;
            break;
          }
        }

        setState(() {
          _connectionState = state;
          _conectado = state.isConnected;

          if (state.isConnected) {
            _dispositivoConectado = encontrado ?? _dispositivoSeleccionado;
            _estado =
                'ESP32S conectado por Bluetooth${_dispositivoConectado == null ? '' : ' a ${_dispositivoConectado!.name}'}.';
          } else {
            _dispositivoConectado = null;
            _estado = 'Bluetooth desconectado.';
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _conectado = false;
          _estado = 'Error de conexión Bluetooth: $error';
        });
      },
    );

    _dataSubscription ??= _bluetooth.onDataReceived.listen(
      (BluetoothData data) {
        final String recibido = data.asString();

        if (!mounted) return;

        setState(() {
          _respuestaBluetooth += recibido;

          if (_respuestaBluetooth.length > 600) {
            _respuestaBluetooth = _respuestaBluetooth.substring(
              _respuestaBluetooth.length - 600,
            );
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _estado = 'Error recibiendo datos Bluetooth: $error';
        });
      },
    );
  }

  Future<void> _verificarEstadoBluetooth() async {
    try {
      final bool soportado = await _bluetooth.isBluetoothSupported();
      final bool encendido = await _bluetooth.isBluetoothEnabled();

      if (!mounted) return;

      setState(() {
        _bluetoothDisponible = soportado;
        _bluetoothEncendido = encendido;

        if (!soportado) {
          _estado = 'Este teléfono no soporta Bluetooth Classic.';
        } else if (!encendido) {
          _estado = 'Bluetooth está apagado. Actívalo en el teléfono.';
        } else {
          _estado = 'Bluetooth listo. Selecciona el ESP32S.';
        }
      });

      if (soportado && encendido) {
        await _cargarDispositivosEmparejados();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'Error verificando Bluetooth: $e';
      });
    }
  }

  Future<void> _encenderBluetooth() async {
    try {
      setState(() {
        _probandoConexion = true;
        _estado = 'Solicitando encender Bluetooth...';
      });

      await _bluetooth.enableBluetooth();
      await _verificarEstadoBluetooth();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'No se pudo encender Bluetooth: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _probandoConexion = false;
      });
    }
  }

  Future<void> _cargarDispositivosEmparejados() async {
    try {
      setState(() {
        _cargandoDispositivos = true;
        _estado = 'Buscando dispositivos Bluetooth emparejados...';
      });

      final List<BluetoothDevice> devices =
          await _bluetooth.getPairedDevices();

      BluetoothDevice? sugerido;

      if (devices.isNotEmpty) {
        for (final BluetoothDevice device in devices) {
          final String nombre = device.name.toLowerCase();

          if (nombre.contains('robot') ||
              nombre.contains('esp32') ||
              nombre.contains('bt')) {
            sugerido = device;
            break;
          }
        }

        sugerido ??= devices.first;
      }

      if (!mounted) return;

      setState(() {
        _dispositivosEmparejados = devices;

        if (_dispositivoSeleccionado == null && sugerido != null) {
          _dispositivoSeleccionado = sugerido;
        }

        _estado = devices.isEmpty
            ? 'No hay dispositivos emparejados. Empareja primero el ESP32S desde ajustes del teléfono.'
            : 'Dispositivos emparejados cargados. Selecciona el ESP32S y conecta.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'Error cargando dispositivos emparejados: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _cargandoDispositivos = false;
      });
    }
  }

  Future<void> _probarConexion() async {
    FocusScope.of(context).unfocus();

    if (!_bluetoothDisponible) {
      setState(() {
        _estado = 'Este teléfono no soporta Bluetooth Classic.';
      });
      return;
    }

    if (!_bluetoothEncendido) {
      await _encenderBluetooth();
      return;
    }

    if (_conectado) {
      await _desconectar();
      return;
    }

    final BluetoothDevice? device = _dispositivoSeleccionado;

    if (device == null) {
      setState(() {
        _estado = 'Selecciona primero el ESP32S emparejado.';
      });
      return;
    }

    setState(() {
      _probandoConexion = true;
      _estado = 'Conectando con ${device.name}...';
    });

    try {
      await _bluetooth.connect(device.address);

      if (!mounted) return;

      setState(() {
        _conectado = true;
        _dispositivoConectado = device;
        _estado = 'ESP32S conectado correctamente por Bluetooth.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _conectado = false;
        _dispositivoConectado = null;
        _estado =
            'No se pudo conectar. Revisa que Robot_BT esté encendido y emparejado.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _probandoConexion = false;
      });
    }
  }

  Future<void> _desconectar() async {
    setState(() {
      _probandoConexion = true;
      _estado = 'Desconectando Bluetooth...';
    });

    try {
      await _bluetooth.disconnect();

      if (!mounted) return;

      setState(() {
        _conectado = false;
        _dispositivoConectado = null;
        _estado = 'Bluetooth desconectado.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'No se pudo desconectar: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _probandoConexion = false;
      });
    }
  }

  void _enviar(String comando) {
    final String limpio = comando.trim();

    if (limpio.isEmpty) {
      return;
    }

    if (!_conectado && _connectionState?.isConnected != true) {
      setState(() {
        _estado = 'Primero conecta el ESP32S por Bluetooth.';
      });
      return;
    }

    final int ahora = DateTime.now().millisecondsSinceEpoch;
    final bool esParada = limpio == 'mot:0' || limpio == 'todo:parar';

    // Evita saturar al ESP32S con muchos comandos seguidos.
    // Las paradas siempre se envían por seguridad.
    if (!esParada && ahora - _ultimoEnvioMs < 100) {
      return;
    }

    _ultimoEnvioMs = ahora;

    setState(() {
      _enviando = true;
      _ultimoComando = limpio;
      _estado = 'Enviando por Bluetooth: $limpio';
    });

    unawaited(_enviarAsync(limpio));
  }

  Future<void> _enviarAsync(String comando) async {
    try {
      await _bluetooth.sendString('$comando\n');

      if (!mounted) return;

      unawaited(
        EventLogService.instance.log(
          type: 'robot_command',
          source: 'manual_bluetooth',
          action: comando,
          success: true,
          detail: 'Comando enviado por Bluetooth',
        ),
      );

      setState(() {
        _enviando = false;
        _conectado = true;
        _estado = 'Comando enviado correctamente por Bluetooth.';
      });
    } catch (e) {
      if (!mounted) return;

      unawaited(
        EventLogService.instance.log(
          type: 'robot_command',
          source: 'manual_bluetooth',
          action: comando,
          success: false,
          detail: 'Error Bluetooth: $e',
        ),
      );

      setState(() {
        _enviando = false;
        _conectado = false;
        _estado = 'No se pudo enviar el comando por Bluetooth: $e';
      });
    }
  }

  Future<void> _seguroParar() async {
    if (!_conectado && _connectionState?.isConnected != true) {
      setState(() {
        _estado = 'No hay conexión Bluetooth. No se pudo enviar parada segura.';
      });
      return;
    }

    setState(() {
      _enviando = true;
      _ultimoComando = 'todo:parar';
      _estado = 'Enviando parada segura por Bluetooth...';
    });

    try {
      await _bluetooth.sendString('todo:parar\n');

      if (!mounted) return;

      unawaited(
        EventLogService.instance.log(
          type: 'emergency_stop',
          source: 'manual_bluetooth',
          action: 'todo:parar',
          success: true,
          detail: 'Parada segura por Bluetooth',
        ),
      );

      setState(() {
        _enviando = false;
        _conectado = true;
        _estado = 'Robot detenido y colocado en posición segura.';
      });
    } catch (e) {
      if (!mounted) return;

      unawaited(
        EventLogService.instance.log(
          type: 'emergency_stop',
          source: 'manual_bluetooth',
          action: 'todo:parar',
          success: false,
          detail: 'Error Bluetooth: $e',
        ),
      );

      setState(() {
        _enviando = false;
        _conectado = false;
        _estado = 'No se pudo enviar la parada segura por Bluetooth.';
      });
    }
  }

  Color get _statusColor {
    if (_enviando || _probandoConexion || _cargandoDispositivos) {
      return Colors.amberAccent;
    }

    return _conectado ? Colors.greenAccent : Colors.orangeAccent;
  }

  Widget _connectionCard() {
    final Color color = _statusColor;

    return Card(
      color: const Color(0xFF101C2F),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Conexión Bluetooth',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _smallStatusChip(_conectado ? 'Conectado' : 'Sin conexión', color),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DropdownButtonFormField<BluetoothDevice>(
                    value: _dispositivoSeleccionado,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF101C2F),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'ESP32S emparejado',
                      hintText: 'Selecciona Robot_BT',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                      contentPadding: EdgeInsets.only(bottom: 6),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    items: _dispositivosEmparejados.map((BluetoothDevice device) {
                      return DropdownMenuItem<BluetoothDevice>(
                        value: device,
                        child: Text(
                          '${device.name}  (${device.address})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _conectado
                        ? null
                        : (BluetoothDevice? device) {
                            setState(() {
                              _dispositivoSeleccionado = device;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: (_probandoConexion || _cargandoDispositivos)
                        ? null
                        : _probarConexion,
                    icon: _probandoConexion
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _conectado
                                ? Icons.bluetooth_disabled_rounded
                                : Icons.bluetooth_connected_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _probandoConexion
                          ? 'Probando'
                          : _conectado
                              ? 'Desconectar'
                              : 'Conectar',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: IconButton(
                    onPressed: _cargandoDispositivos
                        ? null
                        : _cargarDispositivosEmparejados,
                    icon: _cargandoDispositivos
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    color: Colors.lightBlueAccent,
                    tooltip: 'Actualizar dispositivos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _estado,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Último: $_ultimoComando',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            if (_respuestaBluetooth.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Respuesta: ${_respuestaBluetooth.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _smallStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Card(
      color: const Color(0xFF101C2F),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.greenAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cmdButton(
    String label,
    String comando, {
    IconData? icon,
    bool danger = false,
    bool primary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: _conectado ? () => _enviar(comando) : null,
      icon: Icon(icon ?? Icons.play_arrow_rounded, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: danger
            ? Colors.redAccent
            : primary
                ? const Color(0xFF214C5F)
                : const Color(0xFF1B2A42),
        foregroundColor: danger ? Colors.white : Colors.lightBlueAccent,
        disabledBackgroundColor: const Color(0xFF132033),
        disabledForegroundColor: Colors.white30,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _commandButton(_CommandDef item) {
    return _cmdButton(
      item.label,
      item.command,
      icon: item.icon,
      danger: item.danger,
      primary: item.primary,
    );
  }

  List<Widget> _commandButtons(List<_CommandDef> items) {
    return items.map(_commandButton).toList();
  }

  List<Widget> _servoButtons() {
    final List<Map<String, Object>> servos = [
      {'n': 1, 'label': 'S1 Brazo der.', 'min': 40, 'centro': 90, 'max': 140},
      {'n': 2, 'label': 'S2 Hombro der.', 'min': 70, 'centro': 115, 'max': 160},
      {'n': 3, 'label': 'S3 Brazo izq.', 'min': 20, 'centro': 75, 'max': 130},
      {'n': 4, 'label': 'S4 Hombro izq.', 'min': 20, 'centro': 75, 'max': 130},
      {'n': 5, 'label': 'S5 Cabeza sí', 'min': 5, 'centro': 50, 'max': 100},
      {'n': 6, 'label': 'S6 Cuello no', 'min': 65, 'centro': 90, 'max': 115},
    ];

    final List<Widget> buttons = [];

    for (final Map<String, Object> servo in servos) {
      final int n = servo['n'] as int;
      final String label = servo['label'] as String;
      final int min = servo['min'] as int;
      final int centro = servo['centro'] as int;
      final int max = servo['max'] as int;

      buttons.add(_cmdButton('$label min', 'sr$n:$min', icon: Icons.remove));
      buttons.add(_cmdButton('$label centro', 'sr$n:$centro', icon: Icons.adjust));
      buttons.add(_cmdButton('$label max', 'sr$n:$max', icon: Icons.add));
    }

    return buttons;
  }

  Widget _customCommandCard() {
    return Card(
      color: const Color(0xFF101C2F),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.terminal_rounded, color: Colors.greenAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Comando personalizado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCommandController,
                    enabled: _conectado,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _conectado
                          ? 'Ejemplo: fac:10, mov:90, sr1:120'
                          : 'Conecta Bluetooth para enviar comandos',
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      disabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    onSubmitted: (String value) => _enviar(value),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _conectado
                      ? () {
                          _enviar(_customCommandController.text);
                          _customCommandController.clear();
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bluetoothOffCard() {
    return Card(
      color: const Color(0xFF101C2F),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orangeAccent.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_disabled_rounded,
                color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _estado,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _probandoConexion ? null : _encenderBluetooth,
              icon: const Icon(Icons.bluetooth_rounded),
              label: const Text('Encender'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mostrarAvisoBluetooth =
        _bluetoothDisponible && !_bluetoothEncendido;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Modo Manual Bluetooth'),
        backgroundColor: const Color(0xFF101C2F),
        actions: [
          TextButton.icon(
            onPressed: _conectado ? _seguroParar : null,
            icon: const Icon(Icons.warning_rounded, color: Colors.redAccent),
            label: const Text(
              'Seguro / Parar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          physics: const BouncingScrollPhysics(),
          children: [
            if (mostrarAvisoBluetooth) _bluetoothOffCard() else _connectionCard(),
            _section(
              title: 'Motores',
              icon: Icons.gamepad_rounded,
              subtitle: 'Control básico de desplazamiento del robot.',
              children: _commandButtons(_motorCommands),
            ),
            _section(
              title: 'Movimientos del robot',
              icon: Icons.smart_toy_rounded,
              subtitle: 'Acciones programadas de brazos, cabeza y cuello.',
              children: _commandButtons(_movementCommands),
            ),
            _section(
              title: 'Velocidad de servos',
              icon: Icons.speed_rounded,
              subtitle: 'Ajusta la velocidad de brazos, cabeza y cuello.',
              children: _commandButtons(_speedCommands),
            ),
            _section(
              title: 'Rostro / expresiones',
              icon: Icons.face_rounded,
              subtitle: 'Expresiones completas de ojos y boca.',
              children: _commandButtons(_faceCommands),
            ),
            _section(
              title: 'Ojo derecho',
              icon: Icons.visibility_rounded,
              subtitle: 'Cambia únicamente el ojo derecho.',
              children: _commandButtons(_rightEyeCommands),
            ),
            _section(
              title: 'Ojo izquierdo',
              icon: Icons.visibility_rounded,
              subtitle: 'Cambia únicamente el ojo izquierdo.',
              children: _commandButtons(_leftEyeCommands),
            ),
            _section(
              title: 'Boca',
              icon: Icons.mood_rounded,
              subtitle: 'Cambia únicamente la boca.',
              children: _commandButtons(_mouthCommands),
            ),
            _section(
              title: 'Servos individuales',
              icon: Icons.settings_input_component_rounded,
              subtitle: 'Pruebas manuales de cada servo calibrado.',
              children: _servoButtons(),
            ),
            _customCommandCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CommandDef {
  const _CommandDef(
    this.label,
    this.command, {
    this.icon,
    this.danger = false,
    this.primary = false,
  });

  final String label;
  final String command;
  final IconData? icon;
  final bool danger;
  final bool primary;
}

const List<_CommandDef> _motorCommands = [
  _CommandDef('Adelante', 'mot:10', icon: Icons.keyboard_arrow_up_rounded, primary: true),
  _CommandDef('Izquierda', 'mot:30', icon: Icons.keyboard_arrow_left_rounded),
  _CommandDef('Detener', 'mot:0', icon: Icons.stop_circle_rounded, danger: true),
  _CommandDef('Derecha', 'mot:20', icon: Icons.keyboard_arrow_right_rounded),
  _CommandDef('Atrás', 'mot:40', icon: Icons.keyboard_arrow_down_rounded),
];

const List<_CommandDef> _movementCommands = [
  _CommandDef('Levantar brazo izquierdo', 'mov:10', icon: Icons.pan_tool_alt_rounded),
  _CommandDef('Levantar brazo derecho', 'mov:20', icon: Icons.front_hand_rounded),
  _CommandDef('Levantar ambos brazos', 'mov:30', icon: Icons.back_hand_rounded),
  _CommandDef('Decir NO', 'mov:40', icon: Icons.swap_horiz_rounded, primary: true),
  _CommandDef('Brazos abiertos', 'mov:50', icon: Icons.open_in_full_rounded),
  _CommandDef('Hombros alternados', 'mov:60', icon: Icons.compare_arrows_rounded),
  _CommandDef('Hombros juntos', 'mov:70', icon: Icons.sync_alt_rounded),
  _CommandDef('Decir SÍ', 'mov:80', icon: Icons.swap_vert_rounded, primary: true),
  _CommandDef('Saludo', 'mov:90', icon: Icons.waving_hand_rounded, primary: true),
];

const List<_CommandDef> _speedCommands = [
  _CommandDef('Lento', 'vel:10', icon: Icons.speed_rounded),
  _CommandDef('Normal', 'vel:20', icon: Icons.speed_rounded),
  _CommandDef('Rápido', 'vel:30', icon: Icons.speed_rounded, primary: true),
  _CommandDef('Muy rápido', 'vel:40', icon: Icons.speed_rounded),
  _CommandDef('Máximo', 'vel:50', icon: Icons.speed_rounded),
];

const List<_CommandDef> _faceCommands = [
  _CommandDef('Cara feliz', 'fac:10', icon: Icons.sentiment_satisfied_alt_rounded, primary: true),
  _CommandDef('Cara muy feliz', 'fac:20', icon: Icons.sentiment_very_satisfied_rounded),
  _CommandDef('Cara enojada', 'fac:30', icon: Icons.sentiment_dissatisfied_rounded),
  _CommandDef('Cara muy enojada', 'fac:40', icon: Icons.sentiment_very_dissatisfied_rounded),
  _CommandDef('Lengua afuera', 'fac:50', icon: Icons.mood_rounded),
  _CommandDef('Cara muerto', 'fac:60', icon: Icons.close_rounded),
  _CommandDef('Cara asustada', 'fac:70', icon: Icons.crisis_alert_rounded),
  _CommandDef('Cara dormida', 'fac:80', icon: Icons.bedtime_rounded),
  _CommandDef('Cara confundida', 'fac:90', icon: Icons.psychology_alt_rounded),
  _CommandDef('Cara aburrida', 'fac:100', icon: Icons.sentiment_neutral_rounded),
  _CommandDef('Cara enamorada', 'fac:110', icon: Icons.favorite_rounded),
  _CommandDef('Cara de asco', 'fac:120', icon: Icons.sick_rounded),
  _CommandDef('Cara triste', 'fac:130', icon: Icons.mood_bad_rounded),
  _CommandDef('Animar hablar', 'fac:140', icon: Icons.record_voice_over_rounded, primary: true),
  _CommandDef('Normal / seguro', 'todo:parar', icon: Icons.health_and_safety_rounded, danger: true),
];

const List<_CommandDef> _rightEyeCommands = [
  _CommandDef('Derecho neutro', 'old:10', icon: Icons.visibility_rounded),
  _CommandDef('Derecho muy abierto', 'old:20', icon: Icons.visibility_rounded),
  _CommandDef('Derecho cerrado arriba', 'old:30', icon: Icons.visibility_off_rounded),
  _CommandDef('Derecho cerrado abajo', 'old:40', icon: Icons.visibility_off_rounded),
  _CommandDef('Derecho muerto', 'old:50', icon: Icons.close_rounded),
  _CommandDef('Derecho triste', 'old:60', icon: Icons.sentiment_dissatisfied_rounded),
  _CommandDef('Derecho aburrido', 'old:70', icon: Icons.sentiment_neutral_rounded),
  _CommandDef('Derecho enojado', 'old:80', icon: Icons.mood_bad_rounded),
  _CommandDef('Derecho enamorado', 'old:90', icon: Icons.favorite_rounded),
];

const List<_CommandDef> _leftEyeCommands = [
  _CommandDef('Izquierdo neutro', 'ole:10', icon: Icons.visibility_rounded),
  _CommandDef('Izquierdo muy abierto', 'ole:20', icon: Icons.visibility_rounded),
  _CommandDef('Izquierdo cerrado arriba', 'ole:30', icon: Icons.visibility_off_rounded),
  _CommandDef('Izquierdo cerrado abajo', 'ole:40', icon: Icons.visibility_off_rounded),
  _CommandDef('Izquierdo muerto', 'ole:50', icon: Icons.close_rounded),
  _CommandDef('Izquierdo triste', 'ole:60', icon: Icons.sentiment_dissatisfied_rounded),
  _CommandDef('Izquierdo aburrido', 'ole:70', icon: Icons.sentiment_neutral_rounded),
  _CommandDef('Izquierdo enojado', 'ole:80', icon: Icons.mood_bad_rounded),
  _CommandDef('Izquierdo enamorado', 'ole:90', icon: Icons.favorite_rounded),
];

const List<_CommandDef> _mouthCommands = [
  _CommandDef('Boca alegre', 'boc:10', icon: Icons.sentiment_satisfied_alt_rounded, primary: true),
  _CommandDef('Boca muy feliz', 'boc:20', icon: Icons.sentiment_very_satisfied_rounded),
  _CommandDef('Boca triste', 'boc:30', icon: Icons.sentiment_dissatisfied_rounded),
  _CommandDef('Boca muy triste', 'boc:40', icon: Icons.sentiment_very_dissatisfied_rounded),
  _CommandDef('Boca lengua', 'boc:50', icon: Icons.mood_rounded),
  _CommandDef('Boca abierta', 'boc:60', icon: Icons.record_voice_over_rounded),
  _CommandDef('Boca neutra', 'boc:70', icon: Icons.remove_rounded),
  _CommandDef('Boca asco', 'boc:80', icon: Icons.sick_rounded),
  _CommandDef('Boca muy abierta', 'boc:90', icon: Icons.campaign_rounded),
];
