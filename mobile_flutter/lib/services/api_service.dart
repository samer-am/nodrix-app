import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({required this.baseUrl});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

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
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> saveConfig({
    required String type,
    required String sasUrl,
    required String username,
    required String password,
  }) async {
    await http.post(
      _uri('/api/sas/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'sasUrl': sasUrl,
        'username': username,
        'password': password,
      }),
    );
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(_uri('/api/dashboard'));
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendDemoReminders() async {
    final response = await http.post(_uri('/api/reminders/send-demo'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
