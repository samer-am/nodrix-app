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

  Future<Map<String, dynamic>> _postMap(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _readMap(response);
  }

  Future<Map<String, dynamic>> _putMap(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _readMap(response);
  }

  Future<Map<String, dynamic>> testConnection({
    required String type,
    required String sasUrl,
    required String username,
    required String password,
  }) async {
    return _postMap('/api/sas/test-connection', {
      'type': type,
      'sasUrl': sasUrl,
      'username': username,
      'password': password,
    });
  }

  Future<void> saveConfig({
    required String type,
    required String sasUrl,
    required String username,
    required String password,
  }) async {
    final data = await _postMap('/api/sas/save', {
      'type': type,
      'sasUrl': sasUrl,
      'username': username,
      'password': password,
    });
    if (data['ok'] == false) throw Exception(data['message'] ?? 'فشل حفظ الإعدادات');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(_uri('/api/dashboard'));
    return _readMap(response);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final response = await http.get(_uri('/api/customers'));
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    throw Exception('استجابة المشتركين غير صحيحة');
  }

  Future<Map<String, dynamic>> addCustomer(Map<String, dynamic> customer) {
    return _postMap('/api/customers', customer);
  }

  Future<Map<String, dynamic>> updateCustomer(dynamic id, Map<String, dynamic> customer) {
    return _putMap('/api/customers/$id', customer);
  }

  Future<Map<String, dynamic>> addPayment(dynamic id, Map<String, dynamic> payment) {
    return _postMap('/api/customers/$id/payments', payment);
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

  Future<Map<String, dynamic>> getSasStatus() async {
    final response = await http.get(_uri('/api/sas/status'));
    return _readMap(response);
  }

  Future<Map<String, dynamic>> syncSas() async {
    return _postMap('/api/sas/sync', {});
  }

  Future<Map<String, dynamic>> clearMockData() async {
    return _postMap('/api/sas/clear-mock-data', {});
  }
}
