import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';

class AutonomousRobotView extends StatefulWidget {
  const AutonomousRobotView({super.key});

  @override
  State<AutonomousRobotView> createState() => _AutonomousRobotViewState();
}

class _AutonomousRobotViewState extends State<AutonomousRobotView>
    with WidgetsBindingObserver {
  final AiService _aiService = AiService();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _messageController = TextEditingController();

  late stt.SpeechToText _speech;

  CameraController? _cameraController;
  Timer? _faceTimer;

  bool _cameraReady = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _showPanel = true;
  bool _showHistoryOverlay = false;
  bool _faceScanBusy = false;

  bool _waitingForNewPersonName = false;
  bool _isRegisteringNewFace = false;
  bool _cancelFaceRegistration = false;

  String _robotState = 'Activo';
  String _robotEmotion = 'Neutral';
  String _recognizedPerson = 'Sin reconocimiento';
  String _faceRegistrationMessage = '';

  String? _lastGreetingName;
  String? _pendingPersonName;
  DateTime? _ignoreUnknownUntil;

  int _faceRegistrationAttempts = 0;

  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _speech = stt.SpeechToText();

    _initVoice();
    _initCamera();

    _messages.add(
      _ChatMessage(
        text: 'Robot iniciado. Estoy listo para escuchar, ver y conversar.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _faceTimer?.cancel();
    _cameraController?.dispose();
    _speech.stop();
    _tts.stop();
    _messageController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _faceTimer?.cancel();
      controller.dispose();
      setState(() {
        _cameraReady = false;
      });
    }

    if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initVoice() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    await _tts.setLanguage('es-GT');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _robotState = 'Hablando';
          _robotEmotion = 'Hablando';
        });
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          if (!_isRegisteringNewFace && !_waitingForNewPersonName) {
            _robotState = 'Activo';
            _robotEmotion = 'Neutral';
          }
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          if (!_isRegisteringNewFace && !_waitingForNewPersonName) {
            _robotState = 'Activo';
          }
        });
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _cameraReady = false;
          _robotState = 'Sin cámara';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _robotState = 'Activo';
      });

      _startFaceRecognitionTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cameraReady = false;
        _robotState = 'Error de cámara';
      });
    }
  }

  void _startFaceRecognitionTimer() {
    _faceTimer?.cancel();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _scanFace();
      }
    });

    _faceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _scanFace(),
    );
  }

  bool _shouldStartNewPersonFlow(FaceRecognitionResult result) {
    if (result.recognized) return false;

    if (_ignoreUnknownUntil != null &&
        DateTime.now().isBefore(_ignoreUnknownUntil!)) {
      return false;
    }

    final message = result.message.toLowerCase();

    if (message.contains('no se detect')) return false;
    if (message.contains('un solo rostro')) return false;
    if (message.contains('sin conexión')) return false;
    if (message.contains('error')) return false;

    return true;
  }

  Future<void> _scanFace() async {
    final controller = _cameraController;

    if (_faceScanBusy ||
        _waitingForNewPersonName ||
        _isRegisteringNewFace ||
        !_cameraReady ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      _faceScanBusy = true;

      final picture = await controller.takePicture();
      final result = await _aiService.identifyFace(picture.path);

      if (!mounted) return;

      if (result.recognized && result.name.trim().isNotEmpty) {
        final detectedName = result.name.trim();

        setState(() {
          _recognizedPerson = detectedName;
          _robotState = 'Persona reconocida';
        });

        if (_lastGreetingName != detectedName &&
            !_isSpeaking &&
            !_isListening &&
            !_isLoading) {
          _lastGreetingName = detectedName;

          setState(() {
            _messages.add(
              _ChatMessage(
                text: 'Rostro reconocido: $detectedName',
                isUser: false,
              ),
            );
          });

          await _speak('Hola $detectedName, te reconozco.');
        }
      } else if (_shouldStartNewPersonFlow(result)) {
        await _startUnknownPersonFlow();
      } else {
        setState(() {
          _recognizedPerson = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _recognizedPerson = 'Error facial';
      });
    } finally {
      _faceScanBusy = false;
    }
  }

  Future<void> _startUnknownPersonFlow() async {
    if (_waitingForNewPersonName || _isRegisteringNewFace) return;

    _faceTimer?.cancel();

    setState(() {
      _waitingForNewPersonName = true;
      _recognizedPerson = 'Persona nueva';
      _robotState = 'Esperando nombre';
      _robotEmotion = 'Saludando';
      _messages.add(
        _ChatMessage(
          text:
              'Detecté una persona nueva. Estoy esperando su nombre para registrarla.',
          isUser: false,
        ),
      );
    });

    await _speak(
      'Hola, veo un rostro nuevo. Aún no te conozco. ¿Podrías decirme tu nombre para guardarte en mi memoria?',
    );
  }

  String _extractPersonName(String rawText) {
    String name = rawText.trim();
    final lower = name.toLowerCase();

    final patterns = [
      'me llamo ',
      'mi nombre es ',
      'soy ',
      'yo soy ',
      'me dicen ',
    ];

    for (final pattern in patterns) {
      if (lower.startsWith(pattern)) {
        name = name.substring(pattern.length).trim();
        break;
      }
    }

    name = name.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (name.isEmpty) return '';

    return name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final clean = part.trim();
      if (clean.length == 1) return clean.toUpperCase();

      return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _handleNewPersonName(String rawText) async {
    final personName = _extractPersonName(rawText);
    _messageController.clear();

    if (personName.length < 2) {
      await _speak(
        'No logré entender bien tu nombre. Por favor, repítelo o escríbelo en el cuadro de texto.',
      );
      return;
    }

    setState(() {
      _pendingPersonName = personName;
      _waitingForNewPersonName = false;
      _isRegisteringNewFace = true;
      _cancelFaceRegistration = false;
      _faceRegistrationAttempts = 0;
      _faceRegistrationMessage =
          'Preparando escaneo facial para $personName...';
      _robotState = 'Registrando rostro';
      _robotEmotion = 'Neutral';
      _messages.add(
        _ChatMessage(
          text: 'Nombre recibido: $personName',
          isUser: true,
        ),
      );
      _messages.add(
        _ChatMessage(
          text:
              'Muy bien, $personName. Iniciaré el escaneo facial para guardarte en mi memoria.',
          isUser: false,
        ),
      );
    });

    await _speak(
      'Muy bien, $personName. Quédate quieto mirando a la cámara unos segundos para iniciar el escaneo.',
    );

    await Future.delayed(const Duration(seconds: 2));

    await _registerNewFaceLoop(personName);
  }

  Future<void> _registerNewFaceLoop(String personName) async {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _isRegisteringNewFace = false;
        _faceRegistrationMessage = 'La cámara no está lista para escanear.';
        _robotState = 'Error de cámara';
      });
      _startFaceRecognitionTimer();
      return;
    }

    while (mounted && _isRegisteringNewFace && !_cancelFaceRegistration) {
      try {
        if (controller.value.isTakingPicture) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        setState(() {
          _faceRegistrationAttempts++;
          _faceRegistrationMessage =
              'Escaneando rostro... intento $_faceRegistrationAttempts';
          _robotState = 'Escaneando rostro';
        });

        final picture = await controller.takePicture();

        final result = await _aiService.registerFace(
          personName: personName,
          imagePath: picture.path,
        );

        if (!mounted) return;

        if (result.ok) {
          setState(() {
            _isRegisteringNewFace = false;
            _cancelFaceRegistration = false;
            _recognizedPerson = result.personName;
            _lastGreetingName = result.personName;
            _pendingPersonName = null;
            _faceRegistrationMessage = result.message;
            _robotState = 'Rostro guardado';
            _robotEmotion = 'Feliz';
            _messages.add(
              _ChatMessage(
                text: result.message,
                isUser: false,
              ),
            );
          });

          await _speak(
            'Listo, ${result.personName}. Ya te guardé en mi memoria. Ahora puedo reconocerte.',
          );

          _startFaceRecognitionTimer();
          return;
        }

        setState(() {
          _faceRegistrationMessage =
              '${result.message} Intentaré nuevamente. Mantente quieto y con buena luz.';
        });

        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _faceRegistrationMessage =
              'No logré completar el escaneo. Intentaré de nuevo.';
        });

        await Future.delayed(const Duration(seconds: 3));
      }
    }

    if (_cancelFaceRegistration) {
      setState(() {
        _isRegisteringNewFace = false;
        _waitingForNewPersonName = false;
        _pendingPersonName = null;
        _faceRegistrationMessage = 'Escaneo cancelado manualmente.';
        _robotState = 'Activo';
        _robotEmotion = 'Neutral';
        _recognizedPerson = 'Registro cancelado';
        _ignoreUnknownUntil = DateTime.now().add(const Duration(seconds: 30));
      });

      await _speak('Escaneo cancelado. Continuaré con el funcionamiento normal.');

      _startFaceRecognitionTimer();
    }
  }

  Future<void> _cancelNewFaceRegistration() async {
    if (_waitingForNewPersonName && !_isRegisteringNewFace) {
      setState(() {
        _waitingForNewPersonName = false;
        _pendingPersonName = null;
        _robotState = 'Activo';
        _robotEmotion = 'Neutral';
        _recognizedPerson = 'Registro cancelado';
        _faceRegistrationMessage = 'Registro cancelado manualmente.';
        _ignoreUnknownUntil = DateTime.now().add(const Duration(seconds: 30));
      });

      await _speak('Registro cancelado. Continuaré con el funcionamiento normal.');
      _startFaceRecognitionTimer();
      return;
    }

    setState(() {
      _cancelFaceRegistration = true;
      _faceRegistrationMessage = 'Cancelando escaneo...';
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening(sendText: true);
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_isRegisteringNewFace) {
      await _speak('Espera un momento, estoy registrando el rostro.');
      return;
    }

    if (_isSpeaking) {
      await _tts.stop();
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }

    if (!_speechReady) return;

    setState(() {
      _isListening = true;
      _robotState = _waitingForNewPersonName ? 'Escuchando nombre' : 'Escuchando';
    });

    await _speech.listen(
      localeId: 'es_GT',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        setState(() {
          _messageController.text = result.recognizedWords;
        });

        if (result.finalResult) {
          final text = result.recognizedWords.trim();

          await _stopListening(sendText: false);

          if (text.isNotEmpty) {
            if (_waitingForNewPersonName) {
              await _handleNewPersonName(text);
            } else {
              await _sendTextToAI(text);
            }
          }
        }
      },
    );
  }

  Future<void> _stopListening({required bool sendText}) async {
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _isListening = false;
      if (!_waitingForNewPersonName && !_isRegisteringNewFace) {
        _robotState = 'Activo';
      }
    });

    if (sendText) {
      final text = _messageController.text.trim();

      if (text.isNotEmpty) {
        if (_waitingForNewPersonName) {
          await _handleNewPersonName(text);
        } else {
          await _sendTextToAI(text);
        }
      }
    }
  }

  Future<void> _sendFromInput() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    _messageController.clear();

    if (_waitingForNewPersonName) {
      await _handleNewPersonName(text);
      return;
    }

    await _sendTextToAI(text);
  }

  Future<void> _sendTextToAI(String text) async {
    if (_isLoading || text.trim().isEmpty) return;

    if (_isRegisteringNewFace) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Espera un momento, estoy registrando el rostro.',
            isUser: false,
          ),
        );
      });

      await _speak('Espera un momento, estoy registrando el rostro.');
      return;
    }

    await _speech.stop();

    setState(() {
      _isListening = false;
      _isLoading = true;
      _robotState = 'Pensando';
      _messages.add(
        _ChatMessage(
          text: text.trim(),
          isUser: true,
        ),
      );
      _messageController.clear();
    });

    final response = await _aiService.sendMessage(text.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _robotState = 'Respondiendo';
      _robotEmotion = _detectEmotion(response);
      _messages.add(
        _ChatMessage(
          text: response,
          isUser: false,
        ),
      );
    });

    await _speak(response);
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    await _tts.stop();
    await _tts.speak(text);
  }

  String _detectEmotion(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('feliz') ||
        lower.contains('alegre') ||
        lower.contains('genial') ||
        lower.contains('excelente')) {
      return 'Feliz';
    }

    if (lower.contains('triste') ||
        lower.contains('lo siento') ||
        lower.contains('lamento')) {
      return 'Triste';
    }

    if (lower.contains('hola') ||
        lower.contains('saludo') ||
        lower.contains('bienvenido')) {
      return 'Saludando';
    }

    return 'Neutral';
  }

  Color _emotionColor() {
    switch (_robotEmotion) {
      case 'Feliz':
        return Colors.greenAccent;
      case 'Triste':
        return Colors.blueAccent;
      case 'Saludando':
        return Colors.orangeAccent;
      case 'Hablando':
        return Colors.lightBlueAccent;
      default:
        return Colors.white70;
    }
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101C2F),
        title: const Text('Modo Autónomo Activo'),
        actions: [
          IconButton(
            tooltip: 'Escanear rostro ahora',
            onPressed: _scanFace,
            icon: const Icon(Icons.face_retouching_natural_rounded),
          ),
          IconButton(
            tooltip: 'Mostrar historial sobre cámara',
            onPressed: () {
              setState(() {
                _showHistoryOverlay = !_showHistoryOverlay;
              });
            },
            icon: Icon(
              _showHistoryOverlay
                  ? Icons.history_toggle_off_rounded
                  : Icons.history_rounded,
            ),
          ),
          IconButton(
            tooltip: _showPanel ? 'Ocultar panel' : 'Mostrar panel',
            onPressed: () {
              setState(() {
                _showPanel = !_showPanel;
              });
            },
            icon: Icon(
              _showPanel
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: _showPanel ? 6 : 10,
                child: _buildCameraArea(),
              ),
              if (_showPanel) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildRightPanel(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    final controller = _cameraController;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101C2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.lightBlueAccent.withOpacity(0.20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _cameraReady &&
                    controller != null &&
                    controller.value.isInitialized
                ? Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text(
                          'Iniciando cámara...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.smart_toy_rounded,
                  label: _robotState,
                  color: Colors.lightBlueAccent,
                ),
                _InfoChip(
                  icon: Icons.face_rounded,
                  label: _recognizedPerson,
                  color: Colors.greenAccent,
                ),
                _InfoChip(
                  icon: Icons.mood_rounded,
                  label: _robotEmotion,
                  color: _emotionColor(),
                ),
              ],
            ),
          ),
          if (_waitingForNewPersonName || _isRegisteringNewFace)
            Positioned(
              left: 14,
              right: 14,
              top: 70,
              child: _buildFaceRegistrationBanner(),
            ),
          if (_showHistoryOverlay)
            Positioned(
              right: 14,
              top: 14,
              bottom: 14,
              width: 340,
              child: _buildFloatingHistory(),
            ),
          Positioned(
            left: 14,
            bottom: 14,
            right: 14,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceRegistrationBanner() {
    final title = _waitingForNewPersonName
        ? 'Persona nueva detectada'
        : 'Registrando nuevo rostro';

    final message = _waitingForNewPersonName
        ? 'Di tu nombre por voz o escríbelo en el cuadro inferior.'
        : _faceRegistrationMessage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _waitingForNewPersonName
                ? Icons.person_add_alt_1_rounded
                : Icons.face_retouching_natural_rounded,
            color: Colors.orangeAccent,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                if (_isRegisteringNewFace) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _cancelNewFaceRegistration,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleListening,
            icon: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  _isListening ? Colors.redAccent : Colors.lightBlueAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _waitingForNewPersonName
                    ? 'Escribe tu nombre...'
                    : _isListening
                        ? 'Escuchando...'
                        : 'Escribe o usa el micrófono...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF07111F),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _sendFromInput(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _isLoading ? null : _sendFromInput,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
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
              const Expanded(
                child: Text(
                  'Conversación con IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Limpiar historial',
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF07111F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.volume_mute_rounded,
                  color: _isSpeaking ? Colors.greenAccent : Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isSpeaking
                        ? 'El robot está hablando'
                        : 'Voz lista para responder',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildChatList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingHistory() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Historial',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showHistoryOverlay = false;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Expanded(
            child: _buildChatList(compact: true),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList({bool compact = false}) {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No hay mensajes todavía.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];

        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: EdgeInsets.all(compact ? 9 : 11),
            constraints: BoxConstraints(
              maxWidth: compact ? 270 : 340,
            ),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? Colors.lightBlueAccent.withOpacity(0.22)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: msg.isUser
                    ? Colors.lightBlueAccent.withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                height: 1.25,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
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
