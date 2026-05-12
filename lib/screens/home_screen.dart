import 'package:flutter/material.dart';
import '../widgets/mode_card.dart';
import 'autonomous_screen.dart';
import 'manual_wifi_screen.dart';
import 'manual_bluetooth_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      const Text(
                        'Robot Asistente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Selecciona el modo de funcionamiento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 30),

                      ModeCard(
                        title: 'Modo Autónomo con IA',
                        description:
                            'Para el teléfono colocado en el pecho del robot. La IA controla conversación, cámara, voz y movimientos.',
                        icon: Icons.smart_toy_rounded,
                        color: Colors.lightBlueAccent,
                        onTap: () => _goTo(
                          context,
                          const AutonomousScreen(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      ModeCard(
                        title: 'Modo Manual por WiFi',
                        description:
                            'El usuario controla el robot por WiFi. La IA sigue conversando, pero no mueve el robot automáticamente.',
                        icon: Icons.wifi_rounded,
                        color: Colors.greenAccent,
                        onTap: () => _goTo(
                          context,
                          const ManualWifiScreen(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      ModeCard(
                        title: 'Modo Manual por Bluetooth',
                        description:
                            'El usuario controla el robot por Bluetooth. La IA conversa, pero el control físico es manual.',
                        icon: Icons.bluetooth_rounded,
                        color: Colors.deepPurpleAccent,
                        onTap: () => _goTo(
                          context,
                          const ManualBluetoothScreen(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101C2F),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Regla del sistema: solo un teléfono podrá controlar el robot a la vez.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),

                      const SizedBox(height: 20),
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