import 'dart:async';
import 'dart:convert';
import 'dart:io';

class UbntLocalService {
  static const Duration timeout = Duration(seconds: 6);

  Future<Map<String, dynamic>> readLive({
    required Map<String, dynamic> device,
    required String username,
    required String password,
  }) async {
    final host = _text(device['ip'] ?? device['ipAddress']);
    final port = _text(device['port']);
    if (host.isEmpty) {
      return _failure(device, 'IP الجهاز غير محدد');
    }

    final bases = _candidateBases(host, port);
    final errors = <String>[];
    for (final baseUrl in bases) {
      final cookies = <Cookie>[];
      try {
        cookies.addAll(await _login(baseUrl, username, password));
      } catch (error) {
        errors.add('$baseUrl login: $error');
      }

      for (final path in const [
        '/status.cgi',
        '/sta.cgi',
        '/stations.cgi',
        '/iflist.cgi',
        '/api/status',
        '/api/stations',
      ]) {
        try {
          final response = await _request(
            '$baseUrl$path',
            username: username,
            password: password,
            cookies: cookies,
          );
          if (response.statusCode < 200 || response.statusCode >= 300) {
            errors.add('$baseUrl$path HTTP ${response.statusCode}');
            continue;
          }
          final raw = _parseMaybeJson(response.body);
          if (raw == null) {
            errors.add('$baseUrl$path returned non-json');
            continue;
          }
          final clients = _extractClients(raw);
          return {
            'ok': true,
            'real': true,
            'adapter': 'ubnt-local-web$path',
            'device': {
              ...device,
              'status': 'online',
              'lastError': '',
            },
            'stats': {
              ..._extractStats(raw, device, clients),
              'clients': clients.length,
            },
            'deviceClients': clients,
            'customers': const [],
          };
        } catch (error) {
          errors.add('$baseUrl$path $error');
        }
      }
    }

    return _failure(
      device,
      errors.isEmpty
          ? 'تعذر قراءة جهاز UBNT المحلي'
          : 'تعذر قراءة جهاز UBNT المحلي: ${errors.take(3).join(' | ')}',
    );
  }

  List<String> _candidateBases(String host, String port) {
    final clean = host.replaceAll(RegExp(r'/+$'), '');
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return [clean];
    }
    final suffix = port.isEmpty ? '' : ':$port';
    return ['https://$clean$suffix', 'http://$clean$suffix'];
  }

  Future<List<Cookie>> _login(
    String baseUrl,
    String username,
    String password,
  ) async {
    if (username.isEmpty && password.isEmpty) return [];
    final body = Uri(queryParameters: {
      'username': username,
      'password': password,
    }).query;
    final response = await _request(
      '$baseUrl/login.cgi',
      method: 'POST',
      username: username,
      password: password,
      body: body,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      },
    );
    return response.cookies;
  }

  Future<_LocalResponse> _request(
    String url, {
    String method = 'GET',
    String username = '',
    String password = '',
    List<Cookie> cookies = const [],
    Map<String, String> headers = const {},
    String body = '',
  }) async {
    final client = HttpClient();
    client.badCertificateCallback = (certificate, host, port) => true;
    client.connectionTimeout = timeout;
    try {
      final uri = Uri.parse(url);
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json,*/*');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (username.isNotEmpty || password.isNotEmpty) {
        final token = base64Encode(utf8.encode('$username:$password'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
      }
      for (final cookie in cookies) {
        request.cookies.add(cookie);
      }
      if (body.isNotEmpty) {
        request.write(body);
      }
      final response = await request.close().timeout(timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);
      return _LocalResponse(response.statusCode, text, response.cookies);
    } finally {
      client.close(force: true);
    }
  }

  dynamic _parseMaybeJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _failure(Map<String, dynamic> device, String message) {
    return {
      'ok': true,
      'real': true,
      'adapter': 'ubnt-local-web',
      'message': message,
      'device': {
        ...device,
        'status': 'offline',
        'lastError': message,
      },
      'stats': {
        'connected': false,
        'real': true,
        'clients': 0,
        'sampledAt': DateTime.now().toIso8601String(),
      },
      'deviceClients': const [],
      'customers': const [],
    };
  }

  Map<String, dynamic> _extractStats(
    dynamic raw,
    Map<String, dynamic> device,
    List<Map<String, dynamic>> clients,
  ) {
    final map = raw is Map ? raw : const {};
    return {
      'connected': true,
      'real': true,
      'image': 'ubiquiti-radio',
      'clients': clients.length,
      'ccq': _firstValue(map, const ['ccq', 'airmax.quality', 'wireless.ccq']),
      'rxMbps': _asMbps(_firstValue(map, const [
        'rx',
        'rx_rate',
        'rxrate',
        'throughput.rx',
        'rx_bytes',
      ])),
      'txMbps': _asMbps(_firstValue(map, const [
        'tx',
        'tx_rate',
        'txrate',
        'throughput.tx',
        'tx_bytes',
      ])),
      'ethernet': _text(_firstValue(map, const [
        'lan.speed',
        'eth.speed',
        'ethernet',
      ])),
      'noise': _firstValue(map, const [
        'noise',
        'noisefloor',
        'wireless.noise',
      ]),
      'uptime':
          _formatUptime(_firstValue(map, const ['uptime', 'host.uptime'])),
      'distance': _firstValue(map, const ['distance', 'wireless.distance']),
      'frequency': _firstValue(map, const [
        'frequency',
        'freq',
        'wireless.frequency',
      ]),
      'cpu': _firstValue(map, const ['cpu', 'cpu_usage', 'host.cpu']),
      'memory':
          _firstValue(map, const ['memory', 'mem', 'memory_usage', 'host.mem']),
      'rxRate': _firstValue(map, const ['rx_rate', 'rxrate']),
      'txRate': _firstValue(map, const ['tx_rate', 'txrate']),
      'txLatency': _firstValue(map, const ['tx_latency', 'latency']),
      'txPower': _firstValue(map, const ['txpower', 'tx_power']),
      'channelWidth': _firstValue(map, const ['channel_width', 'chanbw']),
      'essid':
          _text(_firstValue(map, const ['essid', 'ssid', 'wireless.essid'])),
      'lanSpeed':
          _text(_firstValue(map, const ['lanSpeed', 'lan.speed', 'eth.speed'])),
      'sampledAt': DateTime.now().toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _extractClients(dynamic raw) {
    final clients = <Map<String, dynamic>>[];
    final seen = <String>{};
    void walk(dynamic value) {
      if (value is List) {
        if (value.length <= 500) {
          for (final item in value) {
            final client = _clientFrom(item);
            if (client != null) {
              final key = '${client['ip']}|${client['mac']}|${client['name']}';
              if (seen.add(key)) clients.add(client);
            }
          }
        }
        for (final item in value) {
          walk(item);
        }
      } else if (value is Map) {
        for (final item in value.values) {
          walk(item);
        }
      }
    }

    walk(raw);
    return clients;
  }

  Map<String, dynamic>? _clientFrom(dynamic raw) {
    if (raw is! Map) return null;
    final ip = _text(_firstValue(raw, const [
      'ip',
      'lastip',
      'last_ip',
      'ipaddr',
      'ipAddress',
      'remote.ip',
      'sta_ip',
      'framedipaddress',
    ]));
    final mac = _text(_firstValue(raw, const [
      'mac',
      'mac_address',
      'aprepeater',
      'remote.mac',
      'callingstationid',
      'calling_station_id',
    ]));
    final name = _text(_firstValue(raw, const [
      'name',
      'hostname',
      'host',
      'remote',
      'station',
      'comment',
    ]));
    final signal = _text(_firstValue(raw, const [
      'signal',
      'signal_strength',
      'rssi',
      'tx_signal',
      'rx_signal',
    ]));
    if (ip.isEmpty && mac.isEmpty && name.isEmpty) return null;
    return {
      'ip': ip,
      'mac': mac,
      'name': name.isEmpty ? 'Client' : name,
      'signal': signal,
      'ccq': _firstValue(raw, const ['ccq', 'quality', 'airmax.quality']),
      'uptime': _formatUptime(_firstValue(raw, const [
        'uptime',
        'assoc_time',
        'connected_time',
      ])),
      'raw': raw,
    };
  }

  dynamic _firstValue(dynamic input, List<String> keys) {
    for (final key in keys) {
      dynamic current = input;
      for (final part in key.split('.')) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else {
          current = null;
          break;
        }
      }
      final text = _text(current);
      if (text.isNotEmpty &&
          text != 'null' &&
          text != 'undefined' &&
          text != '--') {
        return current;
      }
    }
    return '';
  }

  String _formatUptime(dynamic value) {
    final text = _text(value);
    final seconds = int.tryParse(text);
    if (seconds == null || seconds < 0) return text;
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  double _asMbps(dynamic value) {
    final n = double.tryParse(_text(value));
    if (n == null || n <= 0) return 0;
    if (n > 1000000) return double.parse((n / 1000000).toStringAsFixed(2));
    return double.parse(n.toStringAsFixed(2));
  }

  String _text(dynamic value) => value == null ? '' : '$value'.trim();
}

class _LocalResponse {
  final int statusCode;
  final String body;
  final List<Cookie> cookies;

  const _LocalResponse(this.statusCode, this.body, this.cookies);
}
