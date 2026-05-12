import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNetworkDeviceStore {
  static const String devicesKey = 'localNetworkDevices';
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> getDevices({String role = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(devicesKey);
    final rows = raw == null ? <dynamic>[] : jsonDecode(raw);
    final devices = rows is List
        ? rows
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    if (role.trim().isEmpty) return devices;
    return devices
        .where((item) => '${item['role']}'.toLowerCase() == role.toLowerCase())
        .toList();
  }

  Future<Map<String, dynamic>> addDevice(Map<String, dynamic> input) async {
    final name = _text(input['name']);
    final ip = _text(input['ip'] ?? input['ipAddress']);
    if (name.isEmpty || ip.isEmpty) {
      return {'ok': false, 'message': 'اسم الجهاز والـ IP مطلوبان'};
    }

    final deviceId =
        'local_dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final role = _text(input['role']).isEmpty ? 'sector' : _text(input['role']);
    final vendor =
        _text(input['vendor']).isEmpty ? 'ubiquiti' : _text(input['vendor']);
    final device = {
      'id': deviceId,
      'name': name,
      'role': role,
      'vendor': vendor,
      'tower': _text(input['tower']),
      'ip': ip,
      'port': _text(input['port']),
      'connectionMethod': 'local_web',
      'status': 'configured',
      'lastError': '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    final devices = await getDevices();
    devices.removeWhere((item) =>
        _text(item['ip']) == ip && _text(item['role']).toLowerCase() == role);
    devices.add(device);
    await _saveDevices(devices);
    await secureStorage.write(
      key: 'networkDevice.$deviceId.username',
      value: _text(input['username']),
    );
    await secureStorage.write(
      key: 'networkDevice.$deviceId.password',
      value: _text(input['password']),
    );
    return {'ok': true, 'device': device, 'message': 'تم حفظ الجهاز محليًا'};
  }

  Future<void> _saveDevices(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(devicesKey, jsonEncode(devices));
  }

  String _text(dynamic value) => value == null ? '' : '$value'.trim();
}
