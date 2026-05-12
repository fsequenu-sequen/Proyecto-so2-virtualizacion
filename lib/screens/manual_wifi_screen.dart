import 'dart:async';

import 'package:flutter/material.dart';

import '../services/robot_hardware_service.dart';

class ManualWifiScreen extends StatefulWidget {
  const ManualWifiScreen({super.key});

  @override
  State<ManualWifiScreen> createState() => _ManualWifiScreenState();
}

class _ManualWifiScreenState extends State<ManualWifiScreen> {
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.0.112',
  );

  final TextEditingController _customCommandController = TextEditingController();

  late final RobotHardwareService _robot;

  bool _conectado = false;
  bool _probandoConexion = false;
  bool _enviando = false;
  int _ultimoEnvioMs = 0;

  String _estado = 'Listo. Ingresa la IP del ESP32S y prueba la conexión.';
  String _ultimoComando = 'Ninguno';

  @override
  void initState() {
    super.initState();
    _robot = RobotHardwareService(baseUrl: _ipController.text);
  }

  @override
  void dispose() {
    _robot.dispose();
    _ipController.dispose();
    _customCommandController.dispose();
    super.dispose();
  }

  void _actualizarIp() {
    _robot.setBaseUrl(_ipController.text);
  }

  Future<void> _probarConexion() async {
    FocusScope.of(context).unfocus();
    _actualizarIp();

    setState(() {
      _probandoConexion = true;
      _estado = 'Probando conexión con ${_robot.baseUrl}...';
    });

    final bool ok = await _robot.ping();

    if (!mounted) return;

    setState(() {
      _probandoConexion = false;
      _conectado = ok;
      _estado = ok
          ? 'ESP32S conectado correctamente.'
          : 'No respondió. Revisa IP, WiFi y que el ESP32S esté encendido.';
    });
  }

  void _enviar(String comando) {
    final String limpio = comando.trim();

    if (limpio.isEmpty) {
      return;
    }

    _actualizarIp();

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
      _estado = 'Enviando: $limpio';
    });

    unawaited(_enviarAsync(limpio));
  }

  Future<void> _enviarAsync(String comando) async {
    final bool ok = await _robot.enviarComando(comando);

    if (!mounted) return;

    setState(() {
      _enviando = false;
      _conectado = ok;
      _estado = ok
          ? 'Comando enviado correctamente.'
          : 'No respondió al comando. Revisa IP, WiFi o servidor HTTP del ESP32S.';
    });
  }

  Future<void> _seguroParar() async {
    _actualizarIp();

    setState(() {
      _enviando = true;
      _ultimoComando = 'todo:parar';
      _estado = 'Enviando parada segura...';
    });

    final bool ok = await _robot.seguroParar();

    if (!mounted) return;

    setState(() {
      _enviando = false;
      _conectado = ok;
      _estado = ok
          ? 'Robot detenido y colocado en posición segura.'
          : 'No se pudo enviar la parada segura.';
    });
  }

  Color get _statusColor {
    if (_enviando || _probandoConexion) return Colors.amberAccent;
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
                Icon(Icons.wifi_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Conexión WiFi',
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
                  child: TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'IP del ESP32S',
                      hintText: '192.168.0.112',
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
                    onSubmitted: (_) => _probarConexion(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _probandoConexion ? null : _probarConexion,
                    icon: _probandoConexion
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 18),
                    label: Text(_probandoConexion ? 'Probando' : 'Probar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
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
      onPressed: () => _enviar(comando),
      icon: Icon(icon ?? Icons.play_arrow_rounded, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: danger
            ? Colors.redAccent
            : primary
                ? const Color(0xFF214C5F)
                : const Color(0xFF1B2A42),
        foregroundColor: danger ? Colors.white : Colors.lightBlueAccent,
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

    for (final servo in servos) {
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
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Ejemplo: fac:10, mov:90, sr1:120',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    onSubmitted: (value) => _enviar(value),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _enviar(_customCommandController.text),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Modo Manual WiFi'),
        backgroundColor: const Color(0xFF101C2F),
        actions: [
          TextButton.icon(
            onPressed: _seguroParar,
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
            _connectionCard(),
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