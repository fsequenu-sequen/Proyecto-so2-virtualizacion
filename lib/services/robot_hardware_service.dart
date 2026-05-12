import 'dart:async';

import 'package:http/http.dart' as http;

class RobotHardwareService {
  RobotHardwareService({required String baseUrl}) : _client = http.Client() {
    setBaseUrl(baseUrl);
  }

  final http.Client _client;
  late String _baseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    _baseUrl = _normalizarBaseUrl(value);
  }

  static String _normalizarBaseUrl(String value) {
    String url = value.trim();

    if (url.isEmpty) {
      url = '192.168.0.112';
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Future<bool> ping() async {
    try {
      final response = await _client
          .get(_uri('/ping'))
          .timeout(const Duration(milliseconds: 1800));

      return response.statusCode == 200 &&
          response.body.toLowerCase().contains('pong');
    } catch (_) {
      return false;
    }
  }

  Future<bool> enviarComando(String comando) async {
    final String limpio = comando.trim();

    if (limpio.isEmpty) {
      return false;
    }

    try {
      final response = await _client
          .get(
            _uri('/cmd', {
              'c': limpio,
            }),
          )
          .timeout(const Duration(milliseconds: 1200));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> detenerMotores() {
    return enviarComando('mot:0');
  }

  Future<bool> seguroParar() {
    return enviarComando('todo:parar');
  }

  void dispose() {
    _client.close();
  }
}
