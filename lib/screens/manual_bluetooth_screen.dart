import 'package:flutter/material.dart';
import '../widgets/manual_control_panel.dart';
import '../widgets/ai_voice_panel.dart';
import '../widgets/status_panel.dart';

class ManualBluetoothScreen extends StatelessWidget {
  const ManualBluetoothScreen({super.key});

  void _sendVisualCommand(String command) {
    debugPrint('Comando visual Bluetooth: $command');

    // Por ahora no hace nada físico.
    // Más adelante aquí enviaremos comandos al ESP32 por Bluetooth.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Modo Manual Bluetooth'),
        backgroundColor: const Color(0xFF101C2F),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double contentHeight =
                constraints.maxHeight < 520 ? 520 : constraints.maxHeight;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: contentHeight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            const StatusPanel(
                              title: 'Control manual por Bluetooth',
                              status:
                                  'Vista preparada. Los botones aún no envían comandos reales al ESP32.',
                              icon: Icons.bluetooth_rounded,
                              color: Colors.deepPurpleAccent,
                            ),

                            const SizedBox(height: 12),

                            Expanded(
                              child: ManualControlPanel(
                                modeTitle: 'Controles Bluetooth',
                                onCommand: _sendVisualCommand,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        flex: 4,
                        child: AiVoicePanel(
                          title: 'IA en modo manual',
                          subtitle:
                              'La IA conversa contigo, pero no controla los movimientos del robot.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}