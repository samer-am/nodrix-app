import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MikrotikLocalService {
  static const Duration timeout = Duration(seconds: 6);
  static final Map<String, _ByteSample> _byteSamples = {};

  Future<Map<String, dynamic>> readLive({
    required Map<String, dynamic> device,
    required String username,
    required String password,
    bool includeClients = true,
  }) async {
    final host = _text(device['ip'] ?? device['ipAddress']);
    final port = _text(device['port']);
    if (host.isEmpty) return _failure(device, 'IP الجهاز غير محدد');
    final errors = <String>[];
    for (final baseUrl in _candidateBases(host, port)) {
      try {
        final resource = await _getJson(
          '$baseUrl/rest/system/resource',
          username,
          password,
        );
        final identity = await _getJson(
          '$baseUrl/rest/system/identity',
          username,
          password,
          optional: true,
        );
        final interfaces = await _getJson(
          '$baseUrl/rest/interface',
          username,
          password,
          optional: true,
        );
        final clients = includeClients
            ? await _readClients(baseUrl, username, password)
            : <Map<String, dynamic>>[];
        final stats = _statsFrom(
          device: device,
          baseUrl: baseUrl,
          resource: resource,
          identity: identity,
          interfaces: interfaces,
          clients: clients,
        );
        return {
          'ok': true,
          'real': true,
          'adapter': 'mikrotik-rest',
          'device': {
            ...device,
            'status': 'online',
            'lastError': '',
          },
          'stats': stats,
          'deviceClients': clients,
          'customers': const [],
        };
      } catch (error) {
        errors.add('$baseUrl $error');
      }
    }
    return _failure(
      device,
      errors.isEmpty
          ? 'تعذر قراءة جهاز MikroTik المحلي'
          : 'تعذر قراءة جهاز MikroTik المحلي: ${errors.take(2).join(' | ')}',
    );
  }

  Future<Map<String, dynamic>> reboot({
    required Map<String, dynamic> device,
    required String username,
    required String password,
  }) async {
    final host = _text(device['ip'] ?? device['ipAddress']);
    final port = _text(device['port']);
    if (host.isEmpty) return {'ok': false, 'message': 'IP الجهاز غير محدد'};
    final errors = <String>[];
    for (final baseUrl in _candidateBases(host, port)) {
      try {
        final response = await _request(
          '$baseUrl/rest/system/reboot',
          method: 'POST',
          username: username,
          password: password,
        );
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return {'ok': true, 'message': 'تم إرسال أمر إعادة التشغيل'};
        }
        errors.add('$baseUrl HTTP ${response.statusCode}');
      } catch (error) {
        errors.add('$baseUrl $error');
      }
    }
    return {
      'ok': false,
      'message': errors.isEmpty
          ? 'تعذر إرسال أمر إعادة التشغيل'
          : 'تعذر إرسال أمر إعادة التشغيل: ${errors.take(2).join(' | ')}',
    };
  }

  Future<List<Map<String, dynamic>>> _readClients(
    String baseUrl,
    String username,
    String password,
  ) async {
    final clients = <Map<String, dynamic>>[];
    for (final path in const [
      '/rest/interface/wireless/registration-table',
      '/rest/interface/wifi/registration-table',
      '/rest/ip/dhcp-server/lease',
    ]) {
      try {
        final raw = await _getJson(baseUrl + path, username, password);
        if (raw is List) {
          for (final item in raw.whereType<Map>()) {
            final client = _clientFrom(item);
            if (client != null) clients.add(client);
          }
        }
      } catch (_) {
        // RouterOS packages differ; unavailable tables are ignored.
      }
    }
    final seen = <String>{};
    return clients.where((client) {
      final key = '${client['ip']}|${client['mac']}|${client['name']}';
      return seen.add(key);
    }).toList();
  }

  Map<String, dynamic> _statsFrom({
    required Map<String, dynamic> device,
    required String baseUrl,
    required dynamic resource,
    required dynamic identity,
    required dynamic interfaces,
    required List<Map<String, dynamic>> clients,
  }) {
    final res = resource is Map ? resource : const {};
    final id = identity is Map ? identity : const {};
    final list = interfaces is List
        ? interfaces.whereType<Map>().toList()
        : const <Map>[];
    final trafficInterfaces = list
        .where((item) => _text(item['running']).toLowerCase() == 'true')
        .toList();
    final chosen = trafficInterfaces.isNotEmpty ? trafficInterfaces : list;
    var rxBytes = 0.0;
    var txBytes = 0.0;
    var lanSpeed = '';
    for (final item in chosen) {
      rxBytes += _asDouble(item['rx-byte']);
      txBytes += _asDouble(item['tx-byte']);
      if (lanSpeed.isEmpty) lanSpeed = _text(item['actual-mtu']);
    }
    final rates =
        _counterRateMbps('$baseUrl|${_text(device['id'])}', rxBytes, txBytes);
    final totalMem = _asDouble(res['total-memory']);
    final freeMem = _asDouble(res['free-memory']);
    final memory = totalMem > 0 ? ((totalMem - freeMem) / totalMem) * 100 : 0;
    return {
      'connected': true,
      'real': true,
      'image': 'mikrotik-router',
      'clients': clients.length,
      'model':
          _text(res['board-name']).isEmpty ? 'MikroTik' : res['board-name'],
      'firmware': res['version'],
      'essid': id['name'],
      'rxMbps': rates.rx,
      'txMbps': rates.tx,
      'rxBytes': rxBytes,
      'txBytes': txBytes,
      'uptime': _formatUptime(res['uptime']),
      'cpu': res['cpu-load'],
      'memory': double.parse(memory.toStringAsFixed(1)),
      'lanSpeed':
          lanSpeed.isEmpty ? '${chosen.length} interfaces' : 'MTU $lanSpeed',
      'sampledAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic>? _clientFrom(Map raw) {
    final ip = _text(raw['address'] ?? raw['last-ip'] ?? raw['host-address']);
    final mac = _text(raw['mac-address'] ?? raw['caller-id']);
    final name = _bestName(
        raw['host-name'] ?? raw['comment'] ?? raw['interface'], ip, mac);
    final signal = raw['signal-strength'] ?? raw['signal'];
    final rxRate = raw['rx-rate'] ?? raw['rx-rate-set'];
    final txRate = raw['tx-rate'] ?? raw['tx-rate-set'];
    if (ip.isEmpty && mac.isEmpty) return null;
    return {
      'ip': ip,
      'mac': mac,
      'name': name,
      'model': 'MikroTik Client',
      'signal': _formatDbm(signal),
      'noise': '',
      'rxRate': _formatMbps(rxRate),
      'txRate': _formatMbps(txRate),
      'ccq': raw['tx-ccq'] ?? raw['rx-ccq'] ?? raw['uptime'],
      'uptime': _formatUptime(raw['uptime']),
      'raw': raw,
    };
  }

  Future<dynamic> _getJson(
    String url,
    String username,
    String password, {
    bool optional = false,
  }) async {
    final response =
        await _request(url, username: username, password: password);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (optional) return null;
      throw 'HTTP ${response.statusCode}';
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      if (optional) return null;
      throw 'non-json response';
    }
  }

  Future<_LocalResponse> _request(
    String url, {
    String method = 'GET',
    required String username,
    required String password,
  }) async {
    final client = HttpClient();
    client.badCertificateCallback = (certificate, host, port) => true;
    client.connectionTimeout = timeout;
    try {
      final request =
          await client.openUrl(method, Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json,*/*');
      final token = base64Encode(utf8.encode('$username:$password'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
      final response = await request.close().timeout(timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);
      return _LocalResponse(response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  List<String> _candidateBases(String host, String port) {
    final clean = host.replaceAll(RegExp(r'/+$'), '');
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return [clean];
    }
    final suffix = port.isEmpty ? '' : ':$port';
    return ['http://$clean$suffix', 'https://$clean$suffix'];
  }

  Map<String, dynamic> _failure(Map<String, dynamic> device, String message) {
    return {
      'ok': true,
      'real': true,
      'adapter': 'mikrotik-rest',
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

  _RatePair _counterRateMbps(String key, double rx, double tx) {
    final now = DateTime.now();
    final previous = _byteSamples[key];
    _byteSamples[key] = _ByteSample(rx, tx, now);
    if (previous == null) return const _RatePair(0, 0);
    final seconds = now.difference(previous.at).inMilliseconds / 1000;
    if (seconds <= 0) return const _RatePair(0, 0);
    final rxDelta = rx - previous.rx;
    final txDelta = tx - previous.tx;
    if (rxDelta < 0 || txDelta < 0) return const _RatePair(0, 0);
    return _RatePair(
      double.parse(((rxDelta * 8) / seconds / 1000000).toStringAsFixed(2)),
      double.parse(((txDelta * 8) / seconds / 1000000).toStringAsFixed(2)),
    );
  }

  double _rateToMbps(dynamic value) {
    final text = _text(value).toLowerCase();
    if (text.isEmpty) return 0;
    final numberText = text
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9\.\-]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => '');
    final n = double.tryParse(numberText);
    if (n == null || n <= 0) return 0;
    if (text.contains('gbps')) return n * 1000;
    if (text.contains('mbps')) return n;
    if (text.contains('kbps')) return n / 1000;
    if (text.contains('bps')) return n / 1000000;
    if (n >= 1000000) return n / 1000000;
    return n;
  }

  String _formatMbps(dynamic value) {
    final mbps = _rateToMbps(value);
    if (mbps <= 0) return _text(value);
    return '${mbps.toStringAsFixed(mbps >= 10 ? 1 : 2)} Mbps';
  }

  String _formatDbm(dynamic value) {
    final text = _text(value);
    if (text.isEmpty) return '';
    if (text.toLowerCase().contains('dbm')) return text;
    final n = double.tryParse(text);
    if (n == null) return text;
    return '${n.toStringAsFixed(0)} dBm';
  }

  String _formatUptime(dynamic value) {
    final text = _text(value);
    final seconds = int.tryParse(text);
    if (seconds != null) {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (days > 0) return '${days}d ${hours}h ${minutes}m';
      if (hours > 0) return '${hours}h ${minutes}m';
      return '${minutes}m';
    }
    return text;
  }

  String _bestName(dynamic value, String ip, String mac) {
    final text = _text(value);
    if (text.isNotEmpty && text != ip && text != mac) return text;
    if (ip.contains('.')) return 'Client ${ip.split('.').last}';
    if (mac.length >= 4) return 'Client ${mac.substring(mac.length - 4)}';
    return 'Client';
  }

  double _asDouble(dynamic value) =>
      double.tryParse(_text(value).replaceAll(',', '')) ?? 0;

  String _text(dynamic value) => value == null ? '' : '$value'.trim();
}

class _LocalResponse {
  final int statusCode;
  final String body;

  const _LocalResponse(this.statusCode, this.body);
}

class _ByteSample {
  final double rx;
  final double tx;
  final DateTime at;

  const _ByteSample(this.rx, this.tx, this.at);
}

class _RatePair {
  final double rx;
  final double tx;

  const _RatePair(this.rx, this.tx);
}
