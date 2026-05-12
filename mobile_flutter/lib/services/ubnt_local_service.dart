import 'dart:async';
import 'dart:convert';
import 'dart:io';

class UbntLocalService {
  static const Duration timeout = Duration(seconds: 6);
  static final Map<String, List<Cookie>> _cookieJar = {};
  static final Map<String, _ByteSample> _byteSamples = {};

  Future<Map<String, dynamic>> readLive({
    required Map<String, dynamic> device,
    required String username,
    required String password,
    bool includeClients = true,
  }) async {
    final host = _text(device['ip'] ?? device['ipAddress']);
    final port = _text(device['port']);
    if (host.isEmpty) {
      return _failure(device, 'IP الجهاز غير محدد');
    }

    final bases = _candidateBases(host, port);
    final errors = <String>[];
    for (final baseUrl in bases) {
      final sessionKey = '$baseUrl|$username';
      final cookies = List<Cookie>.from(_cookieJar[sessionKey] ?? const []);
      try {
        if (cookies.isEmpty) {
          cookies.addAll(await _login(baseUrl, username, password));
          _cookieJar[sessionKey] = _dedupeCookies(cookies);
        }
      } catch (error) {
        errors.add('$baseUrl login: $error');
      }

      final rawByPath = <String, dynamic>{};
      final clients = <Map<String, dynamic>>[];
      final seenClients = <String>{};
      final paths = includeClients
          ? const [
              '/status.cgi',
              '/sta.cgi',
              '/stations.cgi',
              '/iflist.cgi',
              '/api/status',
              '/api/stations',
            ]
          : const [
              '/status.cgi',
              '/api/status',
            ];
      for (final path in paths) {
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
          rawByPath[path] = raw;
          if (includeClients) {
            for (final client in _extractClients(raw)) {
              final key = '${client['ip']}|${client['mac']}|${client['name']}';
              if (seenClients.add(key)) clients.add(client);
            }
          }
        } catch (error) {
          errors.add('$baseUrl$path $error');
        }
      }
      if (rawByPath.isNotEmpty) {
        final combined = {
          'paths': rawByPath,
          ...rawByPath.values.whereType<Map>().fold<Map<String, dynamic>>(
            <String, dynamic>{},
            (merged, item) => {...merged, ...Map<String, dynamic>.from(item)},
          ),
        };
        return {
          'ok': true,
          'real': true,
          'adapter': 'ubnt-local-web',
          'device': {
            ...device,
            'status': 'online',
            'lastError': '',
          },
          'stats': {
            ..._extractStats(combined, device, clients, baseUrl),
            'clients': clients.length,
          },
          'deviceClients': clients,
          'customers': const [],
        };
      }
    }

    return _failure(
      device,
      errors.isEmpty
          ? 'تعذر قراءة جهاز UBNT المحلي'
          : 'تعذر قراءة جهاز UBNT المحلي: ${errors.take(3).join(' | ')}',
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
      final sessionKey = '$baseUrl|$username';
      final cookies = List<Cookie>.from(_cookieJar[sessionKey] ?? const []);
      try {
        if (cookies.isEmpty) {
          cookies.addAll(await _login(baseUrl, username, password));
          _cookieJar[sessionKey] = _dedupeCookies(cookies);
        }
      } catch (error) {
        errors.add('$baseUrl login: $error');
      }
      for (final path in const ['/reboot.cgi', '/api/reboot']) {
        try {
          final response = await _request(
            '$baseUrl$path',
            method: 'POST',
            username: username,
            password: password,
            cookies: cookies,
          );
          if (response.statusCode >= 200 && response.statusCode < 400) {
            return {'ok': true, 'message': 'تم إرسال أمر إعادة التشغيل'};
          }
          errors.add('$baseUrl$path HTTP ${response.statusCode}');
        } catch (error) {
          errors.add('$baseUrl$path $error');
        }
      }
    }
    return {
      'ok': false,
      'message': errors.isEmpty
          ? 'تعذر إرسال أمر إعادة التشغيل'
          : 'تعذر إرسال أمر إعادة التشغيل: ${errors.take(2).join(' | ')}',
    };
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
    final cookies = <Cookie>[];
    try {
      final first = await _request('$baseUrl/login.cgi?uri=/status.cgi');
      cookies.addAll(first.cookies);
    } catch (_) {
      // Some firmware returns the login page only on /login.cgi.
    }

    final urlEncoded = Uri(queryParameters: {
      'username': username,
      'password': password,
      'uri': '/status.cgi',
    }).query;
    final firstLogin = await _request(
      '$baseUrl/login.cgi',
      method: 'POST',
      cookies: cookies,
      body: urlEncoded,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
        HttpHeaders.refererHeader: '$baseUrl/login.cgi?uri=/status.cgi',
      },
    );
    cookies.addAll(firstLogin.cookies);

    if (firstLogin.statusCode == 200 || firstLogin.statusCode == 302) {
      return _dedupeCookies(cookies);
    }

    final boundary = '----NodrixForm${DateTime.now().millisecondsSinceEpoch}';
    final multipart = [
      '--$boundary',
      'Content-Disposition: form-data; name="username"',
      '',
      username,
      '--$boundary',
      'Content-Disposition: form-data; name="password"',
      '',
      password,
      '--$boundary',
      'Content-Disposition: form-data; name="uri"',
      '',
      '/status.cgi',
      '--$boundary--',
      '',
    ].join('\r\n');
    final secondLogin = await _request(
      '$baseUrl/login.cgi',
      method: 'POST',
      cookies: cookies,
      body: multipart,
      headers: {
        HttpHeaders.contentTypeHeader:
            'multipart/form-data; boundary=$boundary',
        HttpHeaders.refererHeader: '$baseUrl/login.cgi?uri=/status.cgi',
      },
    );
    cookies.addAll(secondLogin.cookies);
    return _dedupeCookies(cookies);
  }

  List<Cookie> _dedupeCookies(List<Cookie> cookies) {
    final byName = <String, Cookie>{};
    for (final cookie in cookies) {
      byName[cookie.name] = cookie;
    }
    return byName.values.toList();
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
    String baseUrl,
  ) {
    final map = raw is Map ? raw : const {};
    final rxBytes = _firstDeep(map, const [
      'rx_bytes',
      'rxbytes',
      'rx_byte',
      'rx_usage',
      'rx',
    ]);
    final txBytes = _firstDeep(map, const [
      'tx_bytes',
      'txbytes',
      'tx_byte',
      'tx_usage',
      'tx',
    ]);
    final memTotal = _asDouble(_firstDeep(map, const [
      'totalram',
      'mem_total',
      'memory_total',
    ]));
    final memFree = _asDouble(_firstDeep(map, const [
      'freeram',
      'mem_free',
      'memory_free',
    ]));
    final memoryPercent = memTotal > 0 && memFree >= 0
        ? ((memTotal - memFree) / memTotal) * 100
        : _firstDeep(map, const ['memory', 'mem', 'memory_usage']);
    final directRxMbps = _rateToMbps(_firstDeep(map, const [
      'rx_rate',
      'rxrate',
      'rxRate',
      'rx_rate_mbps',
      'rx_mbps',
      'throughput.rx',
      'rx_throughput',
      'wlan.rx_rate',
      'wireless.rx_rate',
    ]));
    final directTxMbps = _rateToMbps(_firstDeep(map, const [
      'tx_rate',
      'txrate',
      'txRate',
      'tx_rate_mbps',
      'tx_mbps',
      'throughput.tx',
      'tx_throughput',
      'wlan.tx_rate',
      'wireless.tx_rate',
    ]));
    final counterRates = _counterRateMbps(
      '$baseUrl|${_text(device['id'])}',
      rxBytes,
      txBytes,
    );
    return {
      'connected': true,
      'real': true,
      'image': 'ubiquiti-radio',
      'clients': clients.length,
      'model': _firstDeep(map, const [
        'devmodel',
        'device_model',
        'model',
        'platform',
        'product',
        'host.devmode',
      ]),
      'firmware': _firstDeep(map, const ['fwversion', 'firmware', 'version']),
      'ccq': _firstDeep(map, const [
        'ccq',
        'quality',
        'airmax.quality',
        'airmax_quality',
        'polling_quality',
      ]),
      'rxMbps': directRxMbps > 0 ? directRxMbps : counterRates.rx,
      'txMbps': directTxMbps > 0 ? directTxMbps : counterRates.tx,
      'rxBytes': rxBytes,
      'txBytes': txBytes,
      'ethernet': _text(_firstDeep(map, const [
        'lan.speed',
        'eth.speed',
        'speed',
        'ethernet',
        'plugged',
      ])),
      'noise': _firstDeep(map, const [
        'noise',
        'noisef',
        'noise_floor',
        'noisefloor',
        'noisefloor',
        'wireless.noise',
      ]),
      'uptime': _formatUptime(_firstDeep(map, const ['uptime', 'host.uptime'])),
      'distance': _firstDeep(map, const ['distance', 'wireless.distance']),
      'frequency': _firstDeep(map, const [
        'frequency',
        'freq',
        'freqcur',
        'channel',
        'wireless.frequency',
      ]),
      'cpu': _formatPercent(_firstDeep(map, const [
        'cpu',
        'cpu_usage',
        'cpuusage',
        'cpuload',
        'host.cpu',
      ])),
      'memory': memoryPercent is num
          ? double.parse(memoryPercent.toStringAsFixed(1))
          : memoryPercent,
      'rxRate': _firstDeep(map, const ['rx_rate', 'rxrate', 'rxRate']),
      'txRate': _firstDeep(map, const ['tx_rate', 'txrate', 'txRate']),
      'txLatency': _firstDeep(map, const ['tx_latency', 'latency']),
      'txPower': _firstDeep(map, const ['txpower', 'tx_power', 'txpower_cur']),
      'channelWidth': _firstDeep(map, const [
        'channel_width',
        'chanbw',
        'chwidth',
        'channelwidth',
      ]),
      'essid': _text(_firstDeep(map, const [
        'essid',
        'ssid',
        'aprepeater',
        'wireless.essid',
      ])),
      'lanSpeed': _text(_firstDeep(map, const [
        'lanSpeed',
        'lan.speed',
        'eth.speed',
        'speed',
        'ethernet',
      ])),
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
      'macaddr',
      'aprepeater',
      'remote.mac',
      'callingstationid',
      'calling_station_id',
    ]));
    final model = _text(_firstValue(raw, const [
      'model',
      'devmodel',
      'device_model',
      'platform',
      'product',
      'remote.model',
      'remote.devmodel',
      'remote.platform',
    ]));
    final rawName = _firstValue(raw, const [
      'hostname',
      'name',
      'devname',
      'device_name',
      'remote.hostname',
      'remote.name',
      'remote.devname',
      'host',
      'station',
      'station_name',
      'alias',
      'comment',
    ]);
    final name = _bestClientName(rawName, ip: ip, mac: mac, model: model);
    final signal = _firstDeep(raw, const [
      'signal',
      'signal_strength',
      'signalstrength',
      'rssi',
      'tx_signal',
      'rx_signal',
      'remote.signal',
      'last_signal',
    ]);
    final noise = _firstDeep(raw, const [
      'noise',
      'noisef',
      'noise_floor',
      'noisefloor',
      'noisefloor',
      'remote.noise',
    ]);
    final rxRate = _firstDeep(raw, const [
      'rx_rate',
      'rxrate',
      'rxRate',
      'rx_mbps',
      'rxrate_mbps',
      'rx_data_rate',
      'rx_data_rate_mbps',
      'airmax.rx_rate',
      'stats.rx_rate',
      'remote.rx_rate',
    ]);
    final txRate = _firstDeep(raw, const [
      'tx_rate',
      'txrate',
      'txRate',
      'tx_mbps',
      'txrate_mbps',
      'tx_data_rate',
      'tx_data_rate_mbps',
      'airmax.tx_rate',
      'stats.tx_rate',
      'remote.tx_rate',
    ]);
    final ccq = _firstDeep(raw, const [
      'ccq',
      'quality',
      'airmax.quality',
      'airmax_quality',
      'polling_quality',
    ]);
    final uptime = _firstDeep(raw, const [
      'uptime',
      'assoc_time',
      'connected_time',
      'remote.uptime',
    ]);
    final hasWirelessEvidence = [
      signal,
      noise,
      rxRate,
      txRate,
      ccq,
      uptime,
    ].any((value) => _text(value).isNotEmpty);
    if (ip.isEmpty && !hasWirelessEvidence) return null;
    return {
      'ip': ip,
      'mac': mac,
      'name': name,
      'model': model,
      'signal': _formatDbm(signal),
      'noise': _formatDbm(noise),
      'rxRate': _formatMbps(rxRate),
      'txRate': _formatMbps(txRate),
      'ccq': ccq,
      'uptime': _formatUptime(uptime),
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

  dynamic _firstDeep(dynamic input, List<String> keys) {
    final direct = _firstValue(input, keys);
    if (_text(direct).isNotEmpty) return direct;
    dynamic found = '';
    void walk(dynamic value) {
      if (_text(found).isNotEmpty) return;
      if (value is Map) {
        for (final entry in value.entries) {
          final normalized =
              '${entry.key}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final matched = keys.any((key) =>
              normalized ==
              key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));
          if (matched && _text(entry.value).isNotEmpty) {
            found = entry.value;
            return;
          }
          walk(entry.value);
        }
      } else if (value is List) {
        for (final item in value) {
          walk(item);
        }
      }
    }

    walk(input);
    return found;
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
    double mbps;
    if (text.contains('gbps') || text.contains('gbit')) {
      mbps = n * 1000;
    } else if (text.contains('mbps') || text.contains('mbit')) {
      mbps = n;
    } else if (text.contains('kbps') || text.contains('kbit')) {
      mbps = n / 1000;
    } else if (text.contains('bps') || text.contains('bit')) {
      mbps = n / 1000000;
    } else if (n >= 1000000) {
      mbps = n / 1000000;
    } else {
      mbps = n;
    }
    return double.parse(mbps.toStringAsFixed(mbps >= 10 ? 1 : 2));
  }

  double _asDouble(dynamic value) => double.tryParse(_text(value)) ?? -1;

  _RatePair _counterRateMbps(String key, dynamic rxValue, dynamic txValue) {
    final rx = double.tryParse(_text(rxValue).replaceAll(',', ''));
    final tx = double.tryParse(_text(txValue).replaceAll(',', ''));
    final now = DateTime.now();
    final previous = _byteSamples[key];
    _byteSamples[key] =
        _ByteSample(rx ?? previous?.rx ?? 0, tx ?? previous?.tx ?? 0, now);
    if (rx == null || tx == null || previous == null) {
      return const _RatePair(0, 0);
    }
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

  String _formatMbps(dynamic value) {
    final text = _text(value);
    if (text.isEmpty) return '';
    final mbps = _rateToMbps(value);
    if (mbps <= 0) return text;
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

  String _formatPercent(dynamic value) {
    final text = _text(value);
    if (text.isEmpty) return '';
    if (text.contains('%')) return text.replaceAll('%', '').trim();
    final n = double.tryParse(text);
    if (n == null) return text;
    final percent = n > 0 && n <= 1 ? n * 100 : n;
    return percent.toStringAsFixed(percent >= 10 ? 0 : 1);
  }

  String _bestClientName(
    dynamic value, {
    required String ip,
    required String mac,
    required String model,
  }) {
    final candidate = _text(value);
    if (_isReadableClientName(candidate, ip: ip, mac: mac)) return candidate;
    if (_isReadableClientName(model, ip: ip, mac: mac)) return model;
    final lastOctet = ip.split('.').lastWhere(
          (part) => int.tryParse(part) != null,
          orElse: () => '',
        );
    if (lastOctet.isNotEmpty) return 'Client $lastOctet';
    final cleanMac = mac.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
    if (cleanMac.length >= 4) {
      return 'Client ${cleanMac.substring(cleanMac.length - 4).toUpperCase()}';
    }
    return 'Client';
  }

  bool _isReadableClientName(
    String value, {
    required String ip,
    required String mac,
  }) {
    final text = value.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == '--') return false;
    if (text == ip || text == mac) return false;
    if (text.contains('{') || text.contains('}') || text.contains('=>')) {
      return false;
    }
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(text)) return false;
    if (RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(text)) return false;
    if (RegExp(r'^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$').hasMatch(text)) {
      return false;
    }
    return text.length <= 40;
  }

  String _text(dynamic value) => value == null ? '' : '$value'.trim();
}

class _LocalResponse {
  final int statusCode;
  final String body;
  final List<Cookie> cookies;

  const _LocalResponse(this.statusCode, this.body, this.cookies);
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
