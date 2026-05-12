import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  // CAMBIA ESTA IP POR LA IP REAL DE TU PC DONDE CORRE FASTAPI.
  // Ejemplo: http://192.168.1.10:8000
  static const String baseUrl = 'http://192.168.1.117:8000';

  static const String chatEndpoint = '/chat';
  static const String faceIdentifyEndpoint = '/face/identify';
  static const String faceRegisterEndpoint = '/face/register';

  Future<String> sendMessage(String message) async {
    try {
      final uri = Uri.parse('$baseUrl$chatEndpoint');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return 'No pude comunicarme correctamente con el servidor de IA.';
      }

      final data = jsonDecode(response.body);

      return data['response']?.toString() ??
          data['reply']?.toString() ??
          data['answer']?.toString() ??
          data['message']?.toString() ??
          'Recibí respuesta del servidor, pero no encontré el texto.';
    } catch (e) {
      return 'Error de conexión con el servidor de IA.';
    }
  }

  Future<FaceRecognitionResult> identifyFace(String imagePath) async {
    try {
      final uri = Uri.parse('$baseUrl$faceIdentifyEndpoint');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 20));

      final body = await streamedResponse.stream.bytesToString();

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (streamedResponse.statusCode != 200) {
        final detail = data['detail']?.toString();

        return FaceRecognitionResult(
          recognized: false,
          name: '',
          message: detail ?? 'Error al consultar reconocimiento facial.',
          distance: null,
        );
      }

      final bool recognized = data['recognized'] == true;
      final String name = data['person_name']?.toString() ?? '';
      final String error = data['error']?.toString() ?? '';
      final dynamic distanceValue = data['distance'];

      double? distance;
      if (distanceValue is num) {
        distance = distanceValue.toDouble();
      }

      return FaceRecognitionResult(
        recognized: recognized,
        name: name,
        message: recognized
            ? 'Persona reconocida: $name'
            : error.isNotEmpty
                ? error
                : 'Persona no reconocida',
        distance: distance,
      );
    } catch (e) {
      return FaceRecognitionResult(
        recognized: false,
        name: '',
        message: 'Sin conexión con reconocimiento facial.',
        distance: null,
      );
    }
  }

  // Método compatible por si alguna parte de la app todavía espera solo un String.
  Future<String> recognizeFace(String imagePath) async {
    final result = await identifyFace(imagePath);
    return result.recognized ? result.name : '';
  }

  Future<FaceRegisterResult> registerFace({
    required String personName,
    required String imagePath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$faceRegisterEndpoint');

      final request = http.MultipartRequest('POST', uri);

      // Tu main.py espera este campo con este nombre exacto: person_name
      request.fields['person_name'] = personName;

      // Tu main.py espera el archivo con este nombre exacto: file
      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 20));

      final body = await streamedResponse.stream.bytesToString();

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (streamedResponse.statusCode != 200) {
        final detail = data['detail']?.toString();

        return FaceRegisterResult(
          ok: false,
          personName: personName,
          message: detail ?? 'No se pudo registrar el rostro.',
        );
      }

      return FaceRegisterResult(
        ok: data['ok'] == true,
        personName: data['person_name']?.toString() ?? personName,
        message: data['message']?.toString() ??
            'Rostro registrado correctamente.',
      );
    } catch (e) {
      return FaceRegisterResult(
        ok: false,
        personName: personName,
        message: 'Error de conexión al registrar rostro.',
      );
    }
  }
}

class FaceRecognitionResult {
  final bool recognized;
  final String name;
  final String message;
  final double? distance;

  FaceRecognitionResult({
    required this.recognized,
    required this.name,
    required this.message,
    required this.distance,
  });
}

class FaceRegisterResult {
  final bool ok;
  final String personName;
  final String message;

  FaceRegisterResult({
    required this.ok,
    required this.personName,
    required this.message,
  });
}
