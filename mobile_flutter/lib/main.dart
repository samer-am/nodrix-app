import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/api_service.dart';

const String currentAppVersion = '1.0.7';
const String defaultBackendUrl = 'https://nodrix-app-production.up.railway.app';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const NodrixApp());
}

class AppColors {
  static const bg = Color(0xFF090D12);
  static const panel = Color(0xFF0F151D);
  static const card = Color(0xFF141B24);
  static const cardSoft = Color(0xFF192331);
  static const border = Color(0xFF24303F);
  static const text = Color(0xFFE8EEF6);
  static const muted = Color(0xFF8A97A6);
  static const faint = Color(0xFF566272);
  static const primary = Color(0xFF2E8CFF);
  static const primarySoft = Color(0xFF163251);
  static const green = Color(0xFF20C77A);
  static const red = Color(0xFFEF5F5F);
  static const warning = Color(0xFFF5B547);
  static const purple = Color(0xFF9B7CFF);
}

class NodrixApp extends StatelessWidget {
  const NodrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nodrix',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.purple,
          surface: AppColors.card,
          error: AppColors.red,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
          bodyMedium: TextStyle(fontSize: 13.5, color: AppColors.text),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
          iconTheme: IconThemeData(color: AppColors.text, size: 22),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.faint, fontSize: 13),
          prefixIconColor: AppColors.muted,
          prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(58, 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(58, 42),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
      ),
      home: const SetupPage(),
    );
  }
}

String asText(dynamic value, [String fallback = '—']) {
  final v = value?.toString().trim() ?? '';
  return v.isEmpty ? fallback : v;
}

int asInt(dynamic value) => int.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

String money(dynamic value) {
  final n = asInt(value);
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    b.write(s[i]);
    if (left > 1 && left % 3 == 1) b.write(',');
  }
  return '${b.toString()} د.ع';
}

String todayIso() => DateTime.now().toIso8601String().substring(0, 10);
String afterDays(int days) => DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);

String cleanDateText(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw == '—' || raw.toLowerCase() == 'invalid date') return '';
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
  if (match != null) return match.group(1)!;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '';
  return parsed.toIso8601String().substring(0, 10);
}

String dateLabel(dynamic value) => cleanDateText(value).isEmpty ? 'غير متوفر' : cleanDateText(value);

Color statusColor(String status) {
  switch (status) {
    case 'active':
    case 'online':
      return AppColors.green;
    case 'expires_soon':
      return AppColors.warning;
    case 'expired':
    case 'offline':
      return AppColors.red;
    case 'paused':
      return AppColors.faint;
    default:
      return AppColors.muted;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'فعال';
    case 'expires_soon':
      return 'قريب الانتهاء';
    case 'expired':
      return 'منتهي';
    case 'paused':
      return 'موقوف';
    case 'online':
      return 'متصل';
    case 'offline':
      return 'متوقف';
    default:
      return status.isEmpty ? 'غير معروف' : status;
  }
}

int compareVersions(String a, String b) {
  List<int> parse(String v) => v.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final pa = parse(a), pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class MiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double box;
  const MiniIcon(this.icon, {super.key, this.color = AppColors.primary, this.box = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.28))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(statusLabel(status), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))],
    ]),
  );
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final backend = TextEditingController(text: defaultBackendUrl);
  final type = TextEditingController(text: 'uniquefi');
  final sasUrl = TextEditingController(text: 'https://admin.uniquefi.net');
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool checkingSavedLogin = true;
  String message = '';

  ApiService api() => ApiService(baseUrl: backend.text.trim().replaceFirst(RegExp(r'/+$'), ''));

  @override
  void initState() {
    super.initState();
    restoreLogin();
  }

  Future<void> restoreLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBackend = prefs.getString('backendUrl') ?? defaultBackendUrl;
      backend.text = savedBackend;
      final shouldStayLoggedIn = prefs.getBool('stayLoggedIn') ?? false;
      if (shouldStayLoggedIn) {
        final service = ApiService(baseUrl: savedBackend.replaceFirst(RegExp(r'/+$'), ''));
        final status = await service.getSasStatus();
        if (!mounted) return;
        if (status['ok'] == true) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(api: service)));
          return;
        }
      }
    } catch (_) {
      // Stay on setup screen when the saved session cannot be verified.
    } finally {
      if (mounted) setState(() => checkingSavedLogin = false);
    }
  }

  Future<void> persistLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backendUrl', backend.text.trim().replaceFirst(RegExp(r'/+$'), ''));
    await prefs.setBool('stayLoggedIn', true);
  }

  Future<void> test() async {
    setState(() { loading = true; message = ''; });
    try {
      final result = await api().testConnection(type: type.text.trim(), sasUrl: sasUrl.text.trim(), username: username.text.trim(), password: password.text.trim());
      setState(() => message = result['ok'] == true ? 'الاتصال ناجح' : asText(result['message'], 'فشل الاتصال'));
    } catch (e) {
      setState(() => message = 'فشل الاتصال: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() => loading = true);
    try {
      await api().saveConfig(type: type.text.trim(), sasUrl: sasUrl.text.trim(), username: username.text.trim(), password: password.text.trim());
      await persistLogin();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(api: api())));
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> browserLogin() async {
    setState(() { loading = true; message = ''; });
    try {
      await api().saveConfig(type: type.text.trim(), sasUrl: sasUrl.text.trim(), username: username.text.trim(), password: password.text.trim());
      await persistLogin();
      if (!mounted) return;
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SasWebLoginPage(api: api(), sasUrl: sasUrl.text.trim())));
      if (!mounted) return;
      if (ok == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(api: api())));
      } else {
        setState(() => message = 'لم يتم التقاط جلسة SAS. سجل دخولك داخل المتصفح ثم انتظر ظهور رسالة النجاح.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر فتح تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget input(String label, TextEditingController controller, IconData icon, {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, obscureText: secret, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSavedLogin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),
            const Text('Nodrix', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: .4)),
            const SizedBox(height: 6),
            const Text('اربط لوحة SAS مرة واحدة ثم اجلب كل المشتركين تلقائيًا', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            AppCard(child: Column(children: [
              input('Backend URL', backend, Icons.cloud_rounded),
              input('نوع اللوحة', type, Icons.hub_rounded),
              input('رابط لوحة SAS', sasUrl, Icons.link_rounded),
              input('اسم المستخدم', username, Icons.person_rounded),
              input('كلمة المرور', password, Icons.lock_rounded, secret: true),
              if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(message, style: const TextStyle(color: AppColors.muted))),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: loading ? null : test, child: const Text('اختبار مباشر'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: loading ? null : save, child: Text(loading ? 'انتظر...' : 'حفظ اللوحة'))),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: loading ? null : browserLogin,
                icon: const Icon(Icons.public_rounded, size: 18),
                label: const Text('تسجيل دخول عبر المتصفح'),
              )),
            ])),
          ],
        ),
      ),
    );
  }
}


class SasWebLoginPage extends StatefulWidget {
  final ApiService api;
  final String sasUrl;
  const SasWebLoginPage({super.key, required this.api, required this.sasUrl});
  @override
  State<SasWebLoginPage> createState() => _SasWebLoginPageState();
}

class _SasWebLoginPageState extends State<SasWebLoginPage> {
  late final WebViewController controller;
  bool saving = false;
  String message = 'سجل دخولك داخل لوحة SAS. سيتم حفظ الجلسة تلقائيًا بعد نجاح الدخول.';

  String normalizedUrl() {
    final raw = widget.sasUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final base = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'https://$raw';
    return '$base/#/login';
  }

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => captureToken(),
      ))
      ..loadRequest(Uri.parse(normalizedUrl()));
  }

  String _cleanJsResult(Object? result) {
    var text = result?.toString() ?? '';
    if (text == 'null' || text == 'undefined') return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is String) return decoded.trim();
    } catch (_) {}
    if (text.startsWith('"') && text.endsWith('"') && text.length >= 2) {
      text = text.substring(1, text.length - 1).replaceAll(r'\"', '"');
    }
    return text.trim();
  }

  Future<Map<String, dynamic>> syncUsersInsideWebView(String token) async {
    Future<Map<String, dynamic>> fetchPage(int page) async {
      final js = '''
(async () => {
  const token = localStorage.getItem("sas4_jwt") || sessionStorage.getItem("sas4_jwt") || ${jsonEncode(token)};
  const hasCrypto = !!window.CryptoJS;
  if (!token) {
    return JSON.stringify({ok:false,phase:'token',message:'NO_TOKEN: لم أجد جلسة sas4_jwt داخل المتصفح'});
  }
  if (!hasCrypto) {
    return JSON.stringify({ok:false,phase:'crypto',message:'NO_CRYPTOJS: مكتبة التشفير غير متاحة داخل WebView'});
  }

  const key = "abcdefghijuklmno0123456789012345";
  const payloadData = {
    page: $page,
    count: 10,
    direction: "asc",
    sortBy: "username",
    search: "",
    columns: [
      "id",
      "username",
      "firstname",
      "lastname",
      "expiration",
      "parent_username",
      "name",
      "loan_balance",
      "traffic",
      "remaining_days"
    ]
  };

  try {
    const encrypted = window.CryptoJS.AES.encrypt(JSON.stringify(payloadData), key).toString();
    const res = await fetch("/admin/api/index.php/api/index/user", {
      method: "POST",
      credentials: "include",
      headers: {
        "authorization": "Bearer " + token,
        "content-type": "application/json",
        "accept": "application/json, text/plain, */*"
      },
      body: JSON.stringify({ payload: encrypted })
    });

    const text = await res.text();
    if (!res.ok) {
      return JSON.stringify({
        ok:false,
        phase:'users',
        status:res.status,
        page:$page,
        message:'SAS رفض طلب المستخدمين HTTP ' + res.status,
        body:text.slice(0,1000)
      });
    }

    try {
      const json = JSON.parse(text);
      return JSON.stringify({
        ok:true,
        phase:'users',
        page:$page,
        current_page: json.current_page,
        last_page: json.last_page,
        total: json.total,
        dataLength: Array.isArray(json.data) ? json.data.length : -1,
        data: json
      });
    } catch(e) {
      return JSON.stringify({ok:false,phase:'parse',status:res.status,page:$page,message:'استجابة SAS ليست JSON: '+e.message,body:text.slice(0,1000)});
    }
  } catch(e) {
    return JSON.stringify({ok:false,phase:'exception',page:$page,message:String(e && e.message ? e.message : e)});
  }
})();
''';
      final result = await controller.runJavaScriptReturningResult(js);
      final text = _cleanJsResult(result);
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is String) {
          final decoded2 = jsonDecode(decoded);
          if (decoded2 is Map<String, dynamic>) return decoded2;
        }
      } catch (_) {
        return {'ok': false, 'phase': 'decode', 'message': 'تعذر قراءة نتيجة WebView', 'body': text.length > 1000 ? text.substring(0, 1000) : text};
      }
      return {'ok': false, 'phase': 'decode', 'message': 'استجابة WebView غير صحيحة'};
    }

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final first = await fetchPage(1);
      if (first['ok'] != true) {
        final body = asText(first['body'], '');
        return {
          ...first,
          'message': '${asText(first['message'], 'فشل جلب الصفحة الأولى من SAS')} | phase=${asText(first['phase'], '-')} | status=${asText(first['status'], '-')} | body=${body.substring(0, body.length > 220 ? 220 : body.length)}'
        };
      }

      final data = first['data'];
      if (data is! Map) return {'ok': false, 'phase': 'shape', 'message': 'بنية بيانات SAS غير صحيحة في الصفحة الأولى'};
      List<dynamic> users = (data['data'] is List) ? List<dynamic>.from(data['data'] as List) : <dynamic>[];
      final lastPageRaw = data['last_page'];
      final totalRaw = data['total'];
      final lastPage = (lastPageRaw is num ? lastPageRaw.toInt() : int.tryParse('$lastPageRaw') ?? 1).clamp(1, 200);
      final total = totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? users.length;

      for (int page = 2; page <= lastPage; page++) {
        final next = await fetchPage(page);
        if (next['ok'] != true) {
          final body = asText(next['body'], '');
          return {
            ...next,
            'users': users,
            'message': '${asText(next['message'], 'فشل جلب صفحة من SAS')} - الصفحة $page | phase=${asText(next['phase'], '-')} | status=${asText(next['status'], '-')} | body=${body.substring(0, body.length > 220 ? 220 : body.length)}'
          };
        }
        final nextData = next['data'];
        if (nextData is Map && nextData['data'] is List) {
          users.addAll(List<dynamic>.from(nextData['data'] as List));
        }
      }
      return {'ok': true, 'total': total, 'pages': lastPage, 'users': users};
    } catch (e) {
      return {'ok': false, 'phase': 'flutter', 'message': 'فشل جلب المشتركين من WebView: $e'};
    }
  }

  Future<void> captureToken() async {
    if (saving) return;
    try {
      final result = await controller.runJavaScriptReturningResult("localStorage.getItem('sas4_jwt') || sessionStorage.getItem('sas4_jwt') || ''");
      final token = _cleanJsResult(result);
      if (token.length < 20) return;
      setState(() { saving = true; message = 'تم العثور على جلسة SAS. جاري حفظ الجلسة وجلب المشتركين من داخل المتصفح...'; });
      final saved = await widget.api.saveSasToken(token: token);
      if (!mounted) return;
      if (saved['ok'] != true) {
        setState(() { saving = false; message = asText(saved['message'], 'تعذر حفظ جلسة SAS'); });
        return;
      }

      final fetched = await syncUsersInsideWebView(token);
      if (!mounted) return;
      if (fetched['ok'] == true) {
        final users = (fetched['users'] is List) ? fetched['users'] as List<dynamic> : <dynamic>[];
        final imported = await widget.api.importSasUsers(users: users);
        if (!mounted) return;
        if (imported['ok'] == true) {
          setState(() => message = 'تم حفظ الجلسة وجلب ${imported['total'] ?? users.length} مشترك من SAS.');
          Navigator.pop(context, true);
        } else {
          setState(() { saving = false; message = asText(imported['message'], 'تم حفظ الجلسة لكن فشل حفظ المشتركين في Nodrix'); });
        }
      } else {
        setState(() { saving = false; message = asText(fetched['message'], 'تم حفظ الجلسة لكن فشل جلب المشتركين من المتصفح'); });
      }
    } catch (e) {
      if (mounted) setState(() { saving = false; message = 'تعذر التقاط/مزامنة جلسة SAS: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول SAS')),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.panel,
          child: Text(message, style: const TextStyle(color: AppColors.muted, height: 1.4)),
        ),
        Expanded(child: WebViewWidget(controller: controller)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: saving ? null : captureToken, icon: const Icon(Icons.key_rounded, size: 18), label: const Text('التقاط الجلسة'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: saving ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded, size: 18), label: const Text('إغلاق'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class HomePage extends StatefulWidget {
  final ApiService api;
  const HomePage({super.key, required this.api});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int index = 0;
  int refreshToken = 0;
  Timer? syncTimer;
  bool syncRunning = false;
  DateTime? lastAutoSync;
  void refresh() => setState(() => refreshToken++);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startActiveSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startActiveSync();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      syncTimer?.cancel();
      syncTimer = null;
    }
  }

  void startActiveSync() {
    syncTimer?.cancel();
    runAutoSync();
    syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => runAutoSync());
  }

  Future<void> runAutoSync() async {
    if (syncRunning) return;
    syncRunning = true;
    try {
      final result = await widget.api.syncSas();
      if (mounted && result['ok'] == true) {
        lastAutoSync = DateTime.now();
        refresh();
      }
    } catch (_) {
      // Silent auto-sync. Manual sync page shows detailed errors.
    } finally {
      syncRunning = false;
    }
  }

  Future<void> logout() async {
    syncTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('stayLoggedIn');
    await prefs.remove('backendUrl');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SetupPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomersPage(key: ValueKey('customers-$refreshToken'), api: widget.api),
      DashboardPage(key: ValueKey('dash-$refreshToken'), api: widget.api),
      DevicesPage(key: ValueKey('devices-$refreshToken'), api: widget.api),
      MorePage(key: ValueKey('more-$refreshToken'), api: widget.api, onLogout: logout),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            NavItem(icon: Icons.people_alt_rounded, label: 'المشتركين', selected: index == 0, onTap: () => setState(() => index = 0)),
            NavItem(icon: Icons.bar_chart_rounded, label: 'الرئيسية', selected: index == 1, onTap: () => setState(() => index = 1)),
            NavItem(icon: Icons.router_rounded, label: 'الأجهزة', selected: index == 2, onTap: () => setState(() => index = 2)),
            NavItem(icon: Icons.more_horiz_rounded, label: 'المزيد', selected: index == 3, onTap: () => setState(() => index = 3)),
          ]),
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const NavItem({super.key, required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: selected ? AppColors.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? AppColors.text : AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  const PageFrame({super.key, required this.title, this.subtitle, this.action, required this.children});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SectionTitle(title, subtitle: subtitle)),
            if (action != null) action!,
          ]),
          ...children,
        ],
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  final ApiService api;
  const CustomersPage({super.key, required this.api});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<List<Map<String, dynamic>>> future;
  String query = '';
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    future = widget.api.getCustomers();
  }

  void reload() => setState(() => future = widget.api.getCustomers());

  Future<void> addCustomer() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerFormPage(api: widget.api)));
    if (ok == true) reload();
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> items) {
    return items.where((c) {
      final q = query.trim();
      final matchesQuery = q.isEmpty || '${c['name']} ${c['phone']} ${c['sasUsername']} ${c['tower']} ${c['sector']}'.contains(q);
      final matchesFilter = filter == 'all' || c['status'] == filter;
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Widget chip(String value, String label) {
    final selected = filter == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.muted),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.panel,
      side: const BorderSide(color: AppColors.border),
      onSelected: (_) => setState(() => filter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = applyFilters(snapshot.data ?? []);
        return PageFrame(
          title: 'المشتركين',
          subtitle: 'إدارة الاشتراكات والدفعات',
          action: FilledButton.icon(onPressed: addCustomer, icon: const Icon(Icons.add_rounded, size: 19), label: const Text('إضافة')),
          children: [
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(hintText: 'بحث بالاسم أو الهاتف أو البرج', prefixIcon: Icon(Icons.search_rounded, size: 19)),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              chip('all', 'الكل'), const SizedBox(width: 8), chip('active', 'فعال'), const SizedBox(width: 8), chip('expires_soon', 'قريب'), const SizedBox(width: 8), chip('expired', 'منتهي'), const SizedBox(width: 8), chip('paused', 'موقوف'),
            ])),
            const SizedBox(height: 14),
            if (!snapshot.hasData && !snapshot.hasError) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            if (snapshot.hasError) AppCard(child: Text('تعذر جلب المشتركين: ${snapshot.error}', style: const TextStyle(color: AppColors.red))),
            if (snapshot.hasData && items.isEmpty) const AppCard(child: Text('لا توجد نتائج مطابقة', style: TextStyle(color: AppColors.muted))),
            for (final customer in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: CustomerCard(api: widget.api, customer: customer, onChanged: reload)),
          ],
        );
      },
    );
  }
}

class CustomerCard extends StatelessWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  final VoidCallback onChanged;
  const CustomerCard({super.key, required this.api, required this.customer, required this.onChanged});

  Future<void> details(BuildContext context) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerDetailsPage(api: api, customer: customer)));
    if (ok == true) onChanged();
  }

  Future<void> edit(BuildContext context) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerFormPage(api: api, customer: customer)));
    if (ok == true) onChanged();
  }

  Future<void> pay(BuildContext context) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentPage(api: api, customer: customer)));
    if (ok == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final status = asText(customer['status'], 'active');
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MiniIcon(Icons.person_rounded, color: statusColor(status), box: 32),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(asText(customer['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(asText(customer['phone']), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ])),
          StatusPill(status),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MiniInfo('الباقة', asText(customer['package']))),
          Expanded(child: _MiniInfo('اليوزر', asText(customer['sasUsername'], asText(customer['phone'])))),
          Expanded(child: _MiniInfo('الانتهاء', dateLabel(customer['expiresAt']))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => details(context), child: const Text('تفاصيل'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => edit(context), child: const Text('تعديل'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => pay(context), child: const Text('دفعة'))),
        ]),
      ]),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label, value;
  const _MiniInfo(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.faint, fontSize: 11.5, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
  ]);
}

class CustomerDetailsPage extends StatelessWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  const CustomerDetailsPage({super.key, required this.api, required this.customer});

  Future<void> edit(BuildContext context) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerFormPage(api: api, customer: customer)));
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> pay(BuildContext context) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentPage(api: api, customer: customer)));
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشترك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
        AppCard(color: AppColors.cardSoft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            MiniIcon(Icons.person_rounded, color: statusColor(asText(customer['status'], 'active')), box: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(customer['name']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(asText(customer['phone']), style: const TextStyle(color: AppColors.muted)),
            ])),
            StatusPill(asText(customer['status'], 'active')),
          ]),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(children: [
          InfoLine('الباقة', asText(customer['package']), Icons.speed_rounded),
          InfoLine('السعر', money(customer['price']), Icons.payments_rounded),
          InfoLine('يوزر SAS', asText(customer['sasUsername']), Icons.alternate_email_rounded),
          InfoLine('الأيام المتبقية', asText(customer['sasRemainingDays']), Icons.timelapse_rounded),
          InfoLine('متصل الآن', asText(customer['sasOnlineStatus']) == '1' ? 'نعم' : 'لا', Icons.wifi_rounded),
          InfoLine('ترافيك اليوم', asText(customer['sasDailyTrafficGb']) == '—' ? 'غير متوفر' : '${asText(customer['sasDailyTrafficGb'])} GB', Icons.data_usage_rounded),
          InfoLine('مصدر البيانات', asText(customer['source'], 'manual') == 'sas' ? 'من الساس' : 'يدوي/محلي', Icons.sync_rounded),
          InfoLine('تاريخ البداية', dateLabel(customer['startAt']), Icons.calendar_month_rounded),
          InfoLine('تاريخ الانتهاء', dateLabel(customer['expiresAt']), Icons.event_busy_rounded),
          InfoLine('البرج', asText(customer['tower']), Icons.cell_tower_rounded),
          InfoLine('السكتر', asText(customer['sector']), Icons.settings_input_antenna_rounded),
          InfoLine('الدين', money(customer['debt']), Icons.account_balance_wallet_rounded),
          InfoLine('ملاحظات', asText(customer['notes']), Icons.notes_rounded, last: true),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => edit(context), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('تعديل'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: () => pay(context), icon: const Icon(Icons.payments_rounded, size: 18), label: const Text('تسجيل دفعة'))),
        ]),
      ]),
    );
  }
}

class InfoLine extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool last;
  const InfoLine(this.label, this.value, this.icon, {super.key, this.last = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
        const SizedBox(width: 10),
        Flexible(child: Text(value, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
      ]),
    );
  }
}

class CustomerFormPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? customer;
  const CustomerFormPage({super.key, required this.api, this.customer});
  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  late final TextEditingController name, phone, package, speed, price, tower, sector, address, notes, debt;
  bool saving = false;
  bool get editing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer ?? {};
    name = TextEditingController(text: asText(c['name'], ''));
    phone = TextEditingController(text: asText(c['phone'], ''));
    package = TextEditingController(text: asText(c['package'], 'باقة منزلي'));
    speed = TextEditingController(text: asText(c['speed'], '25 Mbps'));
    price = TextEditingController(text: asText(c['price'], '25000'));
    tower = TextEditingController(text: asText(c['tower'], ''));
    sector = TextEditingController(text: asText(c['sector'], ''));
    address = TextEditingController(text: asText(c['address'], ''));
    notes = TextEditingController(text: asText(c['notes'], ''));
    debt = TextEditingController(text: asText(c['debt'], '0'));
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم المشترك')));
      return;
    }
    setState(() => saving = true);
    final data = {
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'package': package.text.trim(),
      'speed': speed.text.trim(),
      'price': asInt(price.text),
      'tower': tower.text.trim(),
      'sector': sector.text.trim(),
      'address': address.text.trim(),
      'notes': notes.text.trim(),
      'debt': asInt(debt.text),
    };
    try {
      final result = editing ? await widget.api.updateCustomer(widget.customer!['id'], data) : await widget.api.addCustomer(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'تم الحفظ'))));
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(String label, TextEditingController controller, IconData icon, {TextInputType? type, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        textDirection: type == TextInputType.number ? TextDirection.ltr : TextDirection.rtl,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل مشترك' : 'إضافة مشترك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
        AppCard(child: Column(children: [
          input('اسم المشترك', name, Icons.person_rounded),
          input('الهاتف', phone, Icons.phone_rounded, type: TextInputType.phone),
          input('الباقة', package, Icons.speed_rounded),
          input('السرعة', speed, Icons.bolt_rounded),
          input('السعر', price, Icons.payments_rounded, type: TextInputType.number),
          input('الدين', debt, Icons.account_balance_wallet_rounded, type: TextInputType.number),
          input('البرج', tower, Icons.cell_tower_rounded),
          input('السكتر', sector, Icons.settings_input_antenna_rounded),
          AppCard(
            color: AppColors.panel,
            padding: const EdgeInsets.all(12),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('التواريخ والباقات الأساسية ستأتي من الساس عند المزامنة. لا تدخلها يدويًا.', style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 12),
          input('العنوان', address, Icons.location_on_rounded),
          input('ملاحظات', notes, Icons.notes_rounded, maxLines: 2),
          const SizedBox(height: 4),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_rounded, size: 18), label: Text(saving ? 'جاري الحفظ...' : editing ? 'حفظ التعديل' : 'إضافة المشترك')),
        ])),
      ]),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  const PaymentPage({super.key, required this.api, required this.customer});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final TextEditingController amount;
  final note = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: asText(widget.customer['price'], ''));
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final result = await widget.api.addPayment(widget.customer['id'], {'amount': asInt(amount.text), 'note': note.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'تمت العملية'))));
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(String label, TextEditingController c, IconData icon, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, keyboardType: type, textDirection: type == TextInputType.number ? TextDirection.ltr : TextDirection.rtl, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('تسجيل دفعة')), body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
      AppCard(child: Column(children: [
        input('المبلغ', amount, Icons.payments_rounded, type: TextInputType.number),
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('تاريخ الدفع يحسب تلقائيًا. تاريخ الانتهاء يبقى من الساس ولا يكتب يدويًا.', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
        input('ملاحظة', note, Icons.notes_rounded),
        FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_rounded, size: 18), label: const Text('حفظ الدفعة')),
      ])),
    ]));
  }
}

class DashboardPage extends StatelessWidget {
  final ApiService api;
  const DashboardPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: api.getDashboard(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        return PageFrame(title: 'الرئيسية', subtitle: 'نظرة مختصرة على العمل اليومي', children: [
          if (!snapshot.hasData && !snapshot.hasError) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (snapshot.hasError) AppCard(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.red))),
          if (snapshot.hasData) ...[
            AppCard(color: AppColors.cardSoft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const MiniIcon(Icons.stacked_bar_chart_rounded, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Text('ملخص الحسابات', style: Theme.of(context).textTheme.titleMedium))]),
              const SizedBox(height: 14),
              MetricLine('عدد المشتركين', asText(data['totalCustomers'], '0')),
              MetricLine('الدين الكلي', money(data['totalDebt'] ?? 0)),
              MetricLine('دخل اليوم', money(data['incomeToday'] ?? 0), last: true),
            ])),
            const SizedBox(height: 12),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45, children: [
              StatCard('فعال', asText(data['activeCustomers'], '0'), Icons.check_rounded, AppColors.green),
              StatCard('قريب الانتهاء', asText(data['expiresSoon'], '0'), Icons.priority_high_rounded, AppColors.warning),
              StatCard('منتهي', asText(data['expiredCustomers'], '0'), Icons.close_rounded, AppColors.red),
              StatCard('دخل الشهر', money(data['incomeMonth'] ?? 0), Icons.payments_rounded, AppColors.primary),
            ]),
          ],
        ]);
      },
    );
  }
}

class MetricLine extends StatelessWidget {
  final String label, value;
  final bool last;
  const MetricLine(this.label, this.value, {super.key, this.last = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 10),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))]),
  );
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const StatCard(this.title, this.value, this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    MiniIcon(icon, color: color, box: 32),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
  ]));
}

class DevicesPage extends StatelessWidget {
  final ApiService api;
  const DevicesPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return PageFrame(title: 'الأجهزة', subtitle: 'عرض أولي للأجهزة واللنكات', children: [
      FutureBuilder<List<dynamic>>(
        future: api.getSectors(),
        builder: (context, snapshot) => DeviceSection(title: 'السكاترات', items: snapshot.data ?? [], loading: !snapshot.hasData && !snapshot.hasError),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<dynamic>>(
        future: api.getLinks(),
        builder: (context, snapshot) => DeviceSection(title: 'اللنكات', items: snapshot.data ?? [], loading: !snapshot.hasData && !snapshot.hasError),
      ),
    ]);
  }
}

class DeviceSection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool loading;
  const DeviceSection({super.key, required this.title, required this.items, required this.loading});
  @override
  Widget build(BuildContext context) {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (loading) const LinearProgressIndicator(minHeight: 2),
      if (!loading && items.isEmpty) const Text('لا توجد بيانات حاليًا', style: TextStyle(color: AppColors.muted)),
      for (final raw in items) DeviceRow(item: Map<String, dynamic>.from(raw as Map)),
    ]));
  }
}

class DeviceRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const DeviceRow({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final status = asText(item['status'], 'offline');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        MiniIcon(Icons.router_rounded, color: statusColor(status), box: 30),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asText(item['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(asText(item['ip'] ?? item['ipAddress'], 'IP غير محدد'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ])),
        StatusPill(status),
      ]),
    );
  }
}

class MorePage extends StatelessWidget {
  final ApiService api;
  final VoidCallback onLogout;
  const MorePage({super.key, required this.api, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    return PageFrame(title: 'المزيد', subtitle: 'إعدادات وأدوات النظام', children: [
      MoreSection(title: 'الحساب', children: [
        MoreTile(icon: Icons.person_rounded, label: 'حسابي', onTap: () {}),
        MoreTile(icon: Icons.history_rounded, label: 'سجل العمليات', onTap: () {}),
      ]),
      const SizedBox(height: 12),
      MoreSection(title: 'النظام', children: [
        MoreTile(icon: Icons.notifications_rounded, label: 'التنبيهات', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemindersPage(api: api)))),
        MoreTile(icon: Icons.sync_rounded, label: 'مزامنة الساس', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SasSyncPage(api: api)))),
        MoreTile(icon: Icons.system_update_rounded, label: 'التحديثات', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesPage(api: api)))),
        MoreTile(icon: Icons.settings_rounded, label: 'الإعدادات', onTap: () {}),
        MoreTile(icon: Icons.logout_rounded, label: 'تسجيل الخروج من التطبيق', onTap: onLogout),
      ]),
      const SizedBox(height: 12),
      MoreSection(title: 'الدعم لاحقًا', children: [
        MoreTile(icon: Icons.help_outline_rounded, label: 'مركز المساعدة', onTap: () {}),
        MoreTile(icon: Icons.info_outline_rounded, label: 'عن Nodrix - $currentAppVersion', onTap: () {}),
      ]),
    ]);
  }
}

class MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const MoreSection({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    ...children,
  ]));
}

class MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const MoreTile({super.key, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          MiniIcon(icon, box: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.muted),
        ]),
      ),
    );
  }
}


class SasSyncPage extends StatefulWidget {
  final ApiService api;
  const SasSyncPage({super.key, required this.api});
  @override
  State<SasSyncPage> createState() => _SasSyncPageState();
}

class _SasSyncPageState extends State<SasSyncPage> {
  bool loading = false;
  bool clearing = false;
  Map<String, dynamic>? status;
  String message = '';

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  Future<void> loadStatus() async {
    try {
      final result = await widget.api.getSasStatus();
      if (mounted) setState(() => status = result);
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر قراءة حالة الساس: $e');
    }
  }

  Future<void> sync() async {
    setState(() { loading = true; message = ''; });
    try {
      await openBrowserLogin();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clearMock() async {
    setState(() { clearing = true; message = ''; });
    try {
      final result = await widget.api.clearMockData();
      if (!mounted) return;
      setState(() => message = result['ok'] == true ? 'تم تنظيف البيانات الوهمية: ${result['deleted'] ?? 0}' : asText(result['message'], 'فشل التنظيف'));
      await loadStatus();
    } catch (e) {
      if (mounted) setState(() => message = 'خطأ التنظيف: $e');
    } finally {
      if (mounted) setState(() => clearing = false);
    }
  }

  Future<void> openBrowserLogin() async {
    final s = status ?? {};
    final url = asText(s['panelUrl'], '').trim();
    if (url.isEmpty) {
      setState(() => message = 'احفظ رابط لوحة SAS أولًا من شاشة الربط.');
      return;
    }
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SasWebLoginPage(api: widget.api, sasUrl: url)));
    if (!mounted) return;
    if (ok == true) {
      setState(() => message = 'تم حفظ الجلسة وجلب البيانات من داخل المتصفح.');
      await loadStatus();
    }
  }

  Future<void> logoutSas() async {
    setState(() { loading = true; message = ''; });
    try {
      final result = await widget.api.logoutSasSession();
      if (!mounted) return;
      setState(() => message = result['ok'] == true ? 'تم تسجيل الخروج من جلسة SAS المحفوظة' : asText(result['message'], 'فشل تسجيل الخروج'));
      await loadStatus();
    } catch (e) {
      if (mounted) setState(() => message = 'خطأ تسجيل الخروج: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status ?? {};
    final configured = s['configured'] == true;
    return Scaffold(appBar: AppBar(title: const Text('لوحات الساس')), body: ListView(padding: const EdgeInsets.all(18), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('لوحة SAS المرتبطة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(configured ? 'تم حفظ لوحة SAS. يمكنك المزامنة الآن لجلب كل المشتركين من اللوحة.' : 'لم تحفظ لوحة SAS بعد. ارجع إلى شاشة الربط واحفظ الرابط واليوزر والباسورد أولًا.', style: const TextStyle(color: AppColors.muted, height: 1.45)),
        const SizedBox(height: 14),
        MetricLine('قاعدة البيانات', asText(s['database'], 'postgresql')),
        MetricLine('نوع اللوحة', asText(s['source'], 'none')),
        MetricLine('الرابط', asText(s['panelUrl'], 'غير محفوظ')),
        MetricLine('اليوزر', asText(s['panelUsername'], 'غير محفوظ')),
        MetricLine('عدد مشتركين SAS', asText(s['count'], '0')),
        MetricLine('جلسة المتصفح', s['hasToken'] == true ? 'محفوظة' : 'غير محفوظة'),
        MetricLine('آخر مزامنة', dateLabel(s['lastSyncedAt']), last: true),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message, style: const TextStyle(color: AppColors.warning))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: loading ? null : sync, icon: const Icon(Icons.sync_rounded, size: 18), label: Text(loading ? 'جاري المزامنة...' : 'مزامنة عبر المتصفح'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: clearing ? null : clearMock, icon: const Icon(Icons.cleaning_services_rounded, size: 18), label: Text(clearing ? 'تنظيف...' : 'حذف الوهمي'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: openBrowserLogin, icon: const Icon(Icons.public_rounded, size: 18), label: const Text('دخول عبر المتصفح'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: loading ? null : logoutSas, icon: const Icon(Icons.logout_rounded, size: 18), label: const Text('خروج SAS'))),
        ]),
      ])),
      const SizedBox(height: 12),
      const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('طريقة العمل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Text('بسبب Cloudflare تتم المزامنة من داخل المتصفح المدمج نفسه ثم تُرسل النتائج إلى Nodrix. زر مزامنة عبر المتصفح يفتح اللوحة، وإذا كانت الجلسة محفوظة يجلب المشتركين مباشرة.', style: TextStyle(color: AppColors.muted, height: 1.45)),
      ])),
    ]));
  }
}

class RemindersPage extends StatelessWidget {
  final ApiService api;
  const RemindersPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('التنبيهات')), body: FutureBuilder<Map<String, dynamic>>(
      future: api.getReminderPreview(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        return ListView(padding: const EdgeInsets.all(18), children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('معاينة التنبيهات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('عدد الرسائل المقترحة: ${data['count'] ?? 0}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () async {
              final result = await api.sendDemoReminders();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت المحاكاة: ${result['sentCount'] ?? 0}')));
            }, child: const Text('إرسال تجريبي')),
          ])),
        ]);
      },
    ));
  }
}

class UpdatesPage extends StatefulWidget {
  final ApiService api;
  const UpdatesPage({super.key, required this.api});
  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  bool loading = false;
  Map<String, dynamic>? data;
  String message = '';

  Future<void> check() async {
    setState(() { loading = true; message = ''; });
    try {
      final result = await widget.api.getAppVersion();
      setState(() { data = result; message = result['ok'] == true ? 'تم فحص التحديثات' : asText(result['message'], 'تعذر الفحص'); });
    } catch (e) {
      setState(() => message = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> download() async {
    final url = asText(data?['apkUrl'], '');
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط، تم نسخه للحافظة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = asText(data?['latestVersion'], currentAppVersion);
    final hasUpdate = compareVersions(latest, currentAppVersion) > 0;
    return Scaffold(appBar: AppBar(title: const Text('التحديثات')), body: ListView(padding: const EdgeInsets.all(18), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حالة التطبيق', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        MetricLine('النسخة الحالية', currentAppVersion),
        MetricLine('آخر نسخة', latest),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: loading ? null : check, child: Text(loading ? 'جاري الفحص...' : 'فحص التحديثات'))),
          if (data != null) ...[
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: hasUpdate ? download : null, child: const Text('تحميل'))),
          ],
        ]),
      ])),
    ]));
  }
}
