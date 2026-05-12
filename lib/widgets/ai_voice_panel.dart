import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';

class AiVoicePanel extends StatefulWidget {
  final String title;
  final String subtitle;

  const AiVoicePanel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  State<AiVoicePanel> createState() => _AiVoicePanelState();
}

class _AiVoicePanelState extends State<AiVoicePanel> {
  final TextEditingController _messageController = TextEditingController();
  final AiService _aiService = AiService();

  late stt.SpeechToText _speech;
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;
  bool _isListening = false;
  bool _isLoading = false;

  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initVoice();
  }

  Future<void> _initVoice() async {
    _speechReady = await _speech.initialize();

    await _tts.setLanguage('es-GT');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }

    if (!_speechReady) return;

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      localeId: 'es_GT',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();

    setState(() {
      _isListening = false;
    });

    if (_messageController.text.trim().isNotEmpty) {
      await _sendMessage();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isLoading = true;
    });

    final response = await _aiService.sendMessage(text);

    setState(() {
      _messages.add(_ChatMessage(text: response, isUser: false));
      _isLoading = false;
    });

    await _tts.stop();
    await _tts.speak(response);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

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
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: Colors.lightBlueAccent,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),

                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF07111F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Aquí aparecerá la conversación con la IA.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];

                        return Align(
                          alignment: msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(maxWidth: 260),
                            decoration: BoxDecoration(
                              color: msg.isUser
                                  ? Colors.lightBlueAccent.withOpacity(0.22)
                                  : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribe o habla con la IA...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF07111F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isListening ? Colors.redAccent : Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1D3557),
                  padding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.lightBlueAccent.withOpacity(0.35),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({
    required this.text,
    required this.isUser,
  });
}