import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Base URL del API de eventos (sin barra final), por ejemplo `http://142.93.3.189:8080`.
/// Definir al compilar: `flutter run --dart-define=EVENT_LOG_URL=http://TU_IP:8080`
const String _kEventLogBaseUrl = String.fromEnvironment(
  'EVENT_LOG_URL',
  defaultValue: '',
);

class EventLogService {
  EventLogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final EventLogService instance = EventLogService();

  bool get enabled => _kEventLogBaseUrl.trim().isNotEmpty;

  Uri _eventsUri() {
    var base = _kEventLogBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/api/events');
  }

  /// No bloquea la UI; los errores de red se ignoran.
  Future<void> log({
    required String type,
    String? source,
    String? action,
    bool? success,
    String? detail,
    Map<String, dynamic>? payload,
  }) async {
    if (!enabled) {
      return;
    }

    final body = <String, dynamic>{
      'type': type,
      if (source != null) 'source': source,
      if (action != null) 'action': action,
      if (success != null) 'success': success,
      if (detail != null) 'detail': detail,
      if (payload != null) 'payload': payload,
    };

    try {
      final response = await _client
          .post(
            _eventsUri(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'EventLogService: HTTP ${response.statusCode} ${response.body}',
        );
      }
    } catch (e, st) {
      debugPrint('EventLogService: $e\n$st');
    }
  }

  void dispose() {
    _client.close();
  }
}
