import 'package:flutter/material.dart';
import 'autonomous_robot_view.dart';

class AutonomousScreen extends StatefulWidget {
  const AutonomousScreen({super.key});

  @override
  State<AutonomousScreen> createState() => _AutonomousScreenState();
}

class _AutonomousScreenState extends State<AutonomousScreen> {
  bool robotStarted = false;

  void _startRobot() {
    setState(() {
      robotStarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (robotStarted) {
      return const AutonomousRobotView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Modo Autónomo'),
        backgroundColor: const Color(0xFF101C2F),
      ),
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
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101C2F),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.lightBlueAccent.withOpacity(0.35),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.smart_toy_rounded,
                              size: 72,
                              color: Colors.lightBlueAccent,
                            ),

                            SizedBox(height: 18),

                            Text(
                              'Modo Autónomo con IA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(height: 10),

                            Text(
                              'Este modo activa la cámara, micrófono, voz, IA, reconocimiento facial y el control automático del robot.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      ElevatedButton.icon(
                        onPressed: _startRobot,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Iniciar Robot'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
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