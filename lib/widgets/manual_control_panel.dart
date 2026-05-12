import 'package:flutter/material.dart';

class ManualControlPanel extends StatelessWidget {
  final String modeTitle;
  final Function(String command) onCommand;

  const ManualControlPanel({
    super.key,
    required this.modeTitle,
    required this.onCommand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2F),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            modeTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          Expanded(
             child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _DirectionControls(onCommand: onCommand),

                  const SizedBox(height: 18),

                  _SectionTitle('Movimientos'),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _ActionButton(
                        label: 'Saludar',
                        icon: Icons.waving_hand_rounded,
                        onTap: () => onCommand('SALUDAR'),
                      ),
                      _ActionButton(
                        label: 'Brazo Izq.',
                        icon: Icons.pan_tool_alt_rounded,
                        onTap: () => onCommand('BRAZO_IZQUIERDO'),
                      ),
                      _ActionButton(
                        label: 'Brazo Der.',
                        icon: Icons.back_hand_rounded,
                        onTap: () => onCommand('BRAZO_DERECHO'),
                      ),
                      _ActionButton(
                        label: 'Hombros',
                        icon: Icons.accessibility_new_rounded,
                        onTap: () => onCommand('HOMBROS'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle('Expresiones'),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _ActionButton(
                        label: 'Feliz',
                        icon: Icons.sentiment_very_satisfied_rounded,
                        onTap: () => onCommand('CARA_FELIZ'),
                      ),
                      _ActionButton(
                        label: 'Triste',
                        icon: Icons.sentiment_dissatisfied_rounded,
                        onTap: () => onCommand('CARA_TRISTE'),
                      ),
                      _ActionButton(
                        label: 'Enojado',
                        icon: Icons.mood_bad_rounded,
                        onTap: () => onCommand('CARA_ENOJADO'),
                      ),
                      _ActionButton(
                        label: 'Dormido',
                        icon: Icons.bedtime_rounded,
                        onTap: () => onCommand('CARA_DORMIDO'),
                      ),
                      _ActionButton(
                        label: 'Neutral',
                        icon: Icons.sentiment_neutral_rounded,
                        onTap: () => onCommand('CARA_NEUTRAL'),
                      ),
                      _ActionButton(
                        label: 'Hablando',
                        icon: Icons.record_voice_over_rounded,
                        onTap: () => onCommand('CARA_HABLANDO'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionControls extends StatelessWidget {
  final Function(String command) onCommand;

  const _DirectionControls({
    required this.onCommand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MainControlButton(
          label: 'Adelante',
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: () => onCommand('ADELANTE'),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MainControlButton(
                label: 'Izquierda',
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: () => onCommand('IZQUIERDA'),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MainControlButton(
                label: 'Detener',
                icon: Icons.stop_circle_rounded,
                isStop: true,
                onTap: () => onCommand('DETENER'),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MainControlButton(
                label: 'Derecha',
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: () => onCommand('DERECHA'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _MainControlButton(
          label: 'Atrás',
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: () => onCommand('ATRAS'),
        ),
      ],
    );
  }
}

class _MainControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isStop;
  final VoidCallback onTap;

  const _MainControlButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isStop = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 30),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isStop ? Colors.redAccent : const Color(0xFF1D3557),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16243A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}