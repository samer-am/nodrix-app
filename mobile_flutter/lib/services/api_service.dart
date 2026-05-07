import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({required this.baseUrl});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _readMap(http.Response response) async {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'ok': false, 'message': 'استجابة غير متوقعة من السيرفر'};
    } catch (_) {
      return {
        'ok': false,
        'message': 'تعذر قراءة استجابة السيرفر',
        'statusCode': response.statusCode,
        'body': response.body,
      };
    }
  }

  Future<Map<String, dynamic>> testConnection({
    required String type,
    required String sasUrl,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/api/sas/test-connection'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'sasUrl': sasUrl,
        'username': username,
        'password': password,
      }),
    );
    return _readMap(response);
  }

  Future<void> saveConfig({
    required String type,
    required String sasUrl,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/api/sas/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'sasUrl': sasUrl,
        'username': username,
        'password': password,
      }),
    );
    if (response.statusCode >= 400) {
      final data = await _readMap(response);
      throw Exception(data['message'] ?? 'فشل حفظ الإعدادات');
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(_uri('/api/dashboard'));
    return _readMap(response);
  }

  Future<List<dynamic>> getCustomers() async {
    final response = await http.get(_uri('/api/customers'));
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> getSectors() async {
    final response = await http.get(_uri('/api/sectors'));
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> getLinks() async {
    final response = await http.get(_uri('/api/links'));
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getReminderPreview() async {
    final response = await http.get(_uri('/api/reminders/preview'));
    return _readMap(response);
  }

  Future<Map<String, dynamic>> sendDemoReminders() async {
    final response = await http.post(_uri('/api/reminders/send-demo'));
    return _readMap(response);
  }

  Future<Map<String, dynamic>> getAppVersion() async {
    final response = await http.get(_uri('/api/app-version'));
    return _readMap(response);
  }
}
