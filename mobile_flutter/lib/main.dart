import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';
import 'services/local_network_device_store.dart';
import 'services/mikrotik_local_service.dart';
import 'services/ubnt_local_service.dart';

const String currentAppVersion = '1.0.9';
const String defaultBackendUrl = 'https://nodrix-app-production.up.railway.app';
const FlutterSecureStorage secureStorage = FlutterSecureStorage();
final LocalNetworkDeviceStore localNetworkDevices = LocalNetworkDeviceStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
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
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
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
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          bodyMedium: TextStyle(fontSize: 13.5, color: AppColors.text),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: AppColors.text, size: 22),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.faint, fontSize: 13),
          prefixIconColor: AppColors.muted,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(58, 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(58, 42),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
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

int asInt(dynamic value) =>
    int.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

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
String afterDays(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);

String cleanDateText(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw == '—' || raw.toLowerCase() == 'invalid date')
    return '';
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
  if (match != null) return match.group(1)!;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '';
  return parsed.toIso8601String().substring(0, 10);
}

String dateLabel(dynamic value) =>
    cleanDateText(value).isEmpty ? 'غير متوفر' : cleanDateText(value);

Color statusColor(String status) {
  switch (status) {
    case 'active':
    case 'online':
      return AppColors.green;
    case 'expires_soon':
      return AppColors.warning;
    case 'expired':
    case 'offline':
    case 'configured':
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
    case 'configured':
      return 'غير متصل';
    default:
      return status.isEmpty ? 'غير معروف' : status;
  }
}

DateTime? customerExpiryDateTime(Map<String, dynamic> c) {
  final rawCandidates = [
    c['sasExpiryRaw'],
    c['sasExpiryDateTime'],
    c['expiresAt'],
  ];
  for (final raw in rawCandidates) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value == '—' || value.toLowerCase() == 'invalid date')
      continue;
    final normalized =
        value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
      }
      return parsed;
    }
    final d = cleanDateText(value);
    if (d.isNotEmpty) {
      final parsedDate = DateTime.tryParse(d);
      if (parsedDate != null)
        return DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          23,
          59,
          59,
        );
    }
  }
  return null;
}

Duration? customerRemainingDuration(Map<String, dynamic> c) {
  final exp = customerExpiryDateTime(c);
  if (exp == null) return null;
  return exp.difference(DateTime.now());
}

int? customerRemainingDays(Map<String, dynamic> c) {
  final duration = customerRemainingDuration(c);
  if (duration == null) {
    final raw = c['sasRemainingDays'];
    if (raw != null &&
        raw.toString().trim().isNotEmpty &&
        raw.toString() != 'null') {
      return int.tryParse(raw.toString());
    }
    return null;
  }
  if (duration.isNegative) return -1;
  return (duration.inHours / 24).ceil();
}

String remainingDetailedText(Map<String, dynamic> c) {
  final duration = customerRemainingDuration(c);
  if (duration == null) {
    final days = customerRemainingDays(c);
    if (days == null) return 'غير متوفر';
    if (days < 0) return 'منتهي';
    if (days == 0 || days == 1) return 'أقل من 24 ساعة';
    return '$days يوم';
  }
  if (duration.isNegative) return 'منتهي';
  final hours = duration.inHours;
  if (hours < 1) {
    final minutes = duration.inMinutes.clamp(0, 59);
    return '$minutes دقيقة';
  }
  if (hours < 48) return '$hours ساعة';
  final days = (hours / 24).floor();
  final restHours = hours % 24;
  if (restHours == 0) return '$days يوم';
  return '$days يوم و $restHours ساعة';
}

bool customerIsOnline(Map<String, dynamic> c) =>
    asText(c['sasOnlineStatus'], '0') == '1';

bool customerIsExpired(Map<String, dynamic> c) {
  final duration = customerRemainingDuration(c);
  final status = asText(c['status'], '').toLowerCase();
  if (duration != null) return duration.isNegative;
  final days = customerRemainingDays(c);
  return status == 'expired' || (days != null && days < 0);
}

bool customerExpiresSoon(Map<String, dynamic> c) {
  final duration = customerRemainingDuration(c);
  if (duration != null) return !duration.isNegative && duration.inHours <= 72;
  final days = customerRemainingDays(c);
  return days != null && days > 0 && days <= 3;
}

bool customerIsActive(Map<String, dynamic> c) =>
    !customerIsExpired(c) && asText(c['status'], '').toLowerCase() != 'paused';

num customerDebtValue(Map<String, dynamic> c) {
  final candidates = [
    c['debt'],
    c['debtDays'],
    c['loanBalance'],
    c['sasDebtDays'],
  ];
  for (final value in candidates) {
    if (value == null) continue;
    final n = num.tryParse(value.toString().replaceAll(',', ''));
    if (n != null && n > 0) return n;
  }
  return 0;
}

num customerDailyTraffic(Map<String, dynamic> c) {
  final n = num.tryParse(
    asText(c['sasDailyTrafficGb'], '0').replaceAll(',', ''),
  );
  return n ?? 0;
}

String compactTrafficLabel(Map<String, dynamic> c) {
  final n = customerDailyTraffic(c);
  if (n <= 0) return '0 GB';
  return '${n.toStringAsFixed(n >= 10 ? 1 : 2)} GB';
}

Color remainingBadgeColor(int? days) {
  if (days == null) return AppColors.faint;
  if (days <= 0) return AppColors.red;
  if (days <= 3) return AppColors.warning;
  return AppColors.green;
}

String remainingBadgeText(int? days) {
  if (days == null) return 'غير متوفر';
  if (days <= 0) return 'منتهي';
  if (days == 1) return 'أقل من يوم';
  if (days == 2) return 'يومان';
  if (days <= 10) return '$days أيام';
  return '$days يوم';
}

String normalizedSearchText(Map<String, dynamic> c) {
  return [
    c['name'],
    c['phone'],
    c['sasPhone'],
    c['sasUsername'],
    c['package'],
    c['tower'],
    c['sector'],
    c['sasIp'],
  ].map((e) => asText(e, '')).join(' ').toLowerCase();
}

int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('.')
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
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
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double box;
  const MiniIcon(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.box = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class MetricGlyph extends StatelessWidget {
  final String type;
  final Color color;
  final double box;

  const MetricGlyph(this.type, {super.key, required this.color, this.box = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: CustomPaint(painter: _MetricGlyphPainter(type, color)),
    );
  }
}

class _MetricGlyphPainter extends CustomPainter {
  final String type;
  final Color color;

  _MetricGlyphPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withOpacity(.88)
      ..style = PaintingStyle.fill;
    final c = Offset(size.width / 2, size.height / 2);
    switch (type) {
      case 'clients':
        canvas.drawCircle(
            Offset(size.width * .38, size.height * .38), 3.2, fill);
        canvas.drawCircle(
            Offset(size.width * .62, size.height * .38), 3.2, fill);
        canvas.drawArc(
          Rect.fromLTWH(size.width * .20, size.height * .52, size.width * .36,
              size.height * .24),
          3.2,
          2.9,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromLTWH(size.width * .44, size.height * .52, size.width * .36,
              size.height * .24),
          3.2,
          2.9,
          false,
          paint,
        );
        break;
      case 'rx':
        canvas.drawLine(Offset(c.dx, size.height * .22),
            Offset(c.dx, size.height * .72), paint);
        canvas.drawLine(Offset(c.dx, size.height * .72),
            Offset(size.width * .34, size.height * .56), paint);
        canvas.drawLine(Offset(c.dx, size.height * .72),
            Offset(size.width * .66, size.height * .56), paint);
        break;
      case 'tx':
        canvas.drawLine(Offset(c.dx, size.height * .78),
            Offset(c.dx, size.height * .28), paint);
        canvas.drawLine(Offset(c.dx, size.height * .28),
            Offset(size.width * .34, size.height * .44), paint);
        canvas.drawLine(Offset(c.dx, size.height * .28),
            Offset(size.width * .66, size.height * .44), paint);
        break;
      case 'noise':
        for (var i = 0; i < 7; i++) {
          final x = size.width * (.25 + (i % 3) * .18);
          final y = size.height * (.28 + (i ~/ 3) * .18);
          canvas.drawCircle(Offset(x, y), 2.3, fill);
        }
        break;
      case 'cpu':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c, width: size.width * .42, height: size.height * .42),
            const Radius.circular(5),
          ),
          paint,
        );
        for (var i = 0; i < 3; i++) {
          final p = size.width * (.25 + i * .16);
          canvas.drawLine(Offset(p, size.height * .15),
              Offset(p, size.height * .25), paint);
          canvas.drawLine(Offset(p, size.height * .75),
              Offset(p, size.height * .85), paint);
        }
        break;
      case 'memory':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .22, size.height * .30, size.width * .52,
                size.height * .40),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawLine(Offset(size.width * .74, size.height * .40),
            Offset(size.width * .82, size.height * .40), paint);
        canvas.drawLine(Offset(size.width * .74, size.height * .60),
            Offset(size.width * .82, size.height * .60), paint);
        break;
      default:
        canvas.drawCircle(c, size.width * .18, paint);
        canvas.drawCircle(c, size.width * .06, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ],
        ),
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

  ApiService api() =>
      ApiService(baseUrl: backend.text.trim().replaceFirst(RegExp(r'/+$'), ''));

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
        final service = ApiService(
          baseUrl: savedBackend.replaceFirst(RegExp(r'/+$'), ''),
        );
        final status = await service.getSasStatus();
        if (!mounted) return;
        if (status['ok'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(api: service)),
          );
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
    await prefs.setString(
      'backendUrl',
      backend.text.trim().replaceFirst(RegExp(r'/+$'), ''),
    );
    await prefs.setBool('stayLoggedIn', true);
  }

  Future<void> test() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final result = await api().testConnection(
        type: type.text.trim(),
        sasUrl: sasUrl.text.trim(),
        username: username.text.trim(),
        password: password.text.trim(),
      );
      setState(
        () => message = result['ok'] == true
            ? 'الاتصال ناجح'
            : asText(result['message'], 'فشل الاتصال'),
      );
    } catch (e) {
      setState(() => message = 'فشل الاتصال: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() => loading = true);
    try {
      await api().saveConfig(
        type: type.text.trim(),
        sasUrl: sasUrl.text.trim(),
        username: username.text.trim(),
        password: password.text.trim(),
      );
      await persistLogin();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(api: api())),
      );
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> browserLogin() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      await api().saveConfig(
        type: type.text.trim(),
        sasUrl: sasUrl.text.trim(),
        username: username.text.trim(),
        password: password.text.trim(),
      );
      await persistLogin();
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SasWebLoginPage(api: api(), sasUrl: sasUrl.text.trim()),
        ),
      );
      if (!mounted) return;
      if (ok == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(api: api())),
        );
      } else {
        setState(
          () => message =
              'لم يتم التقاط جلسة SAS. سجل دخولك داخل المتصفح ثم انتظر ظهور رسالة النجاح.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر فتح تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget input(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool secret = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19),
        ),
      ),
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
            const Text(
              'Nodrix',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'اربط لوحة SAS مرة واحدة ثم اجلب كل المشتركين تلقائيًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                children: [
                  input('Backend URL', backend, Icons.cloud_rounded),
                  input('نوع اللوحة', type, Icons.hub_rounded),
                  input('رابط لوحة SAS', sasUrl, Icons.link_rounded),
                  input('اسم المستخدم', username, Icons.person_rounded),
                  input(
                    'كلمة المرور',
                    password,
                    Icons.lock_rounded,
                    secret: true,
                  ),
                  if (message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        message,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: loading ? null : test,
                          child: const Text('اختبار مباشر'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading ? null : save,
                          child: Text(loading ? 'انتظر...' : 'حفظ اللوحة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : browserLogin,
                      icon: const Icon(Icons.public_rounded, size: 18),
                      label: const Text('تسجيل دخول عبر المتصفح'),
                    ),
                  ),
                ],
              ),
            ),
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
  Completer<String>? _sasJsCompleter;
  String message =
      'سجل دخولك داخل لوحة SAS. سيتم حفظ الجلسة تلقائيًا بعد نجاح الدخول.';

  String normalizedUrl() {
    final raw = widget.sasUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final base = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    return '$base/#/login';
  }

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NodrixSas',
        onMessageReceived: (JavaScriptMessage msg) {
          final c = _sasJsCompleter;
          if (c != null && !c.isCompleted) c.complete(msg.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => captureToken()),
      )
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

  Future<Map<String, dynamic>> _runSasPageFetchViaChannel(
    int page,
    String token,
  ) async {
    final completer = Completer<String>();
    _sasJsCompleter = completer;
    final js = '''
(function () {
  const fallbackToken = __TOKEN__;
  const pageNumber = __PAGE__;
  function finish(obj) {
    try {
      NodrixSas.postMessage(JSON.stringify(obj));
    } catch (e) {
      // Nothing else is possible here. Flutter timeout will handle it.
    }
  }
  (async function () {
    try {
      const token = localStorage.getItem("sas4_jwt") || sessionStorage.getItem("sas4_jwt") || fallbackToken;
      if (!token) {
        finish({ok:false,phase:'token',message:'NO_TOKEN: لم أجد جلسة sas4_jwt داخل المتصفح'});
        return;
      }
      if (!window.CryptoJS || !window.CryptoJS.AES) {
        finish({ok:false,phase:'crypto',message:'NO_CRYPTOJS: مكتبة التشفير غير متاحة داخل WebView'});
        return;
      }

      const key = "abcdefghijuklmno0123456789012345";
      const payloadData = {
        page: pageNumber,
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
          "remaining_days",
          "static_ip",
          "ip",
          "ip_address",
          "framed_ip_address"
        ]
      };

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
        finish({
          ok:false,
          phase:'users',
          status:res.status,
          page:pageNumber,
          message:'SAS رفض طلب المستخدمين HTTP ' + res.status,
          body:text.slice(0,1000)
        });
        return;
      }

      try {
        const json = JSON.parse(text);
        finish({
          ok:true,
          phase:'users',
          page:pageNumber,
          current_page: json.current_page,
          last_page: json.last_page,
          total: json.total,
          dataLength: Array.isArray(json.data) ? json.data.length : -1,
          data: json
        });
      } catch(e) {
        finish({ok:false,phase:'parse',status:res.status,page:pageNumber,message:'استجابة SAS ليست JSON: '+e.message,body:text.slice(0,1000)});
      }
    } catch(e) {
      finish({ok:false,phase:'exception',page:pageNumber,message:String(e && e.message ? e.message : e)});
    }
  })();
})();
'''
        .replaceAll('__TOKEN__', jsonEncode(token))
        .replaceAll('__PAGE__', '$page');

    try {
      await controller.runJavaScript(js);
      final text = await completer.future.timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return {
        'ok': false,
        'phase': 'decode',
        'message': 'استجابة WebView غير صحيحة',
        'body': text.length > 1000 ? text.substring(0, 1000) : text,
      };
    } on TimeoutException {
      return {
        'ok': false,
        'phase': 'timeout',
        'page': page,
        'message': 'انتهى وقت انتظار WebView أثناء جلب صفحة SAS',
      };
    } catch (e) {
      return {
        'ok': false,
        'phase': 'flutter-js',
        'page': page,
        'message': 'فشل تنفيذ JavaScript داخل WebView: $e',
      };
    } finally {
      if (identical(_sasJsCompleter, completer)) _sasJsCompleter = null;
    }
  }

  Future<Map<String, dynamic>> syncUsersInsideWebView(String token) async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final first = await _runSasPageFetchViaChannel(1, token);
      if (first['ok'] != true) {
        final body = asText(first['body'], '');
        return {
          ...first,
          'message':
              '${asText(first['message'], 'فشل جلب الصفحة الأولى من SAS')} | phase=${asText(first['phase'], '-')} | status=${asText(first['status'], '-')} | body=${body.substring(0, body.length > 220 ? 220 : body.length)}',
        };
      }

      final data = first['data'];
      if (data is! Map)
        return {
          'ok': false,
          'phase': 'shape',
          'message': 'بنية بيانات SAS غير صحيحة في الصفحة الأولى',
        };
      List<dynamic> users = (data['data'] is List)
          ? List<dynamic>.from(data['data'] as List)
          : <dynamic>[];
      final lastPageRaw = data['last_page'];
      final totalRaw = data['total'];
      final lastPage = (lastPageRaw is num
              ? lastPageRaw.toInt()
              : int.tryParse('$lastPageRaw') ?? 1)
          .clamp(1, 200);
      final total = totalRaw is num
          ? totalRaw.toInt()
          : int.tryParse('$totalRaw') ?? users.length;

      for (int page = 2; page <= lastPage; page++) {
        final next = await _runSasPageFetchViaChannel(page, token);
        if (next['ok'] != true) {
          final body = asText(next['body'], '');
          return {
            ...next,
            'users': users,
            'message':
                '${asText(next['message'], 'فشل جلب صفحة من SAS')} - الصفحة $page | phase=${asText(next['phase'], '-')} | status=${asText(next['status'], '-')} | body=${body.substring(0, body.length > 220 ? 220 : body.length)}',
          };
        }
        final nextData = next['data'];
        if (nextData is Map && nextData['data'] is List) {
          users.addAll(List<dynamic>.from(nextData['data'] as List));
        }
      }
      return {'ok': true, 'total': total, 'pages': lastPage, 'users': users};
    } catch (e) {
      return {
        'ok': false,
        'phase': 'flutter',
        'message': 'فشل جلب المشتركين من WebView: $e',
      };
    }
  }

  Future<void> captureToken() async {
    if (saving) return;
    try {
      final result = await controller.runJavaScriptReturningResult(
        "localStorage.getItem('sas4_jwt') || sessionStorage.getItem('sas4_jwt') || ''",
      );
      final token = _cleanJsResult(result);
      if (token.length < 20) return;
      setState(() {
        saving = true;
        message =
            'تم العثور على جلسة SAS. جاري حفظ الجلسة وجلب المشتركين من داخل المتصفح...';
      });
      final saved = await widget.api.saveSasToken(token: token);
      if (!mounted) return;
      if (saved['ok'] != true) {
        setState(() {
          saving = false;
          message = asText(saved['message'], 'تعذر حفظ جلسة SAS');
        });
        return;
      }

      final fetched = await syncUsersInsideWebView(token);
      if (!mounted) return;
      if (fetched['ok'] == true) {
        final users = (fetched['users'] is List)
            ? fetched['users'] as List<dynamic>
            : <dynamic>[];
        final imported = await widget.api.importSasUsers(users: users);
        if (!mounted) return;
        if (imported['ok'] == true) {
          setState(
            () => message =
                'تم حفظ الجلسة وجلب ${imported['total'] ?? users.length} مشترك من SAS.',
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            saving = false;
            message = asText(
              imported['message'],
              'تم حفظ الجلسة لكن فشل حفظ المشتركين في Nodrix',
            );
          });
        }
      } else {
        setState(() {
          saving = false;
          message = asText(
            fetched['message'],
            'تم حفظ الجلسة لكن فشل جلب المشتركين من المتصفح',
          );
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          message = 'تعذر التقاط/مزامنة جلسة SAS: $e';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول SAS')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.panel,
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
          Expanded(child: WebViewWidget(controller: controller)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : captureToken,
                      icon: const Icon(Icons.key_rounded, size: 18),
                      label: const Text('التقاط الجلسة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('إغلاق'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  String customersInitialFilter = 'all';
  Timer? syncTimer;
  bool syncRunning = false;
  DateTime? lastAutoSync;
  void refresh() => setState(() => refreshToken++);

  void openCustomersFilter(String filter) {
    setState(() {
      customersInitialFilter = filter;
      index = 0;
      refreshToken++;
    });
  }

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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      syncTimer?.cancel();
      syncTimer = null;
    }
  }

  void startActiveSync() {
    syncTimer?.cancel();
    runAutoSync();
    syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => runAutoSync(),
    );
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SetupPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomersPage(
        key: ValueKey('customers-$refreshToken-$customersInitialFilter'),
        api: widget.api,
        initialFilter: customersInitialFilter,
      ),
      DashboardPage(
        key: ValueKey('dash-$refreshToken'),
        api: widget.api,
        onOpenFilter: openCustomersFilter,
      ),
      DevicesPage(key: ValueKey('devices-$refreshToken'), api: widget.api),
      MorePage(
        key: ValueKey('more-$refreshToken'),
        api: widget.api,
        onLogout: logout,
      ),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              NavItem(
                icon: Icons.people_alt_rounded,
                label: 'المشتركين',
                selected: index == 0,
                onTap: () => setState(() => index = 0),
              ),
              NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'الرئيسية',
                selected: index == 1,
                onTap: () => setState(() => index = 1),
              ),
              NavItem(
                icon: Icons.router_rounded,
                label: 'الأجهزة',
                selected: index == 2,
                onTap: () => setState(() => index = 2),
              ),
              NavItem(
                icon: Icons.more_horiz_rounded,
                label: 'المزيد',
                selected: index == 3,
                onTap: () => setState(() => index = 3),
              ),
            ],
          ),
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
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.text : AppColors.muted,
                ),
              ),
            ],
          ),
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
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SectionTitle(title, subtitle: subtitle)),
              if (action != null) action!,
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  final ApiService api;
  final String initialFilter;
  const CustomersPage({
    super.key,
    required this.api,
    this.initialFilter = 'all',
  });
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<List<Map<String, dynamic>>> future;
  final TextEditingController searchController = TextEditingController();
  String query = '';
  Set<String> filters = {'all'};
  String sortMode = 'name';

  @override
  void initState() {
    super.initState();
    filters = widget.initialFilter == 'all' ? {'all'} : {widget.initialFilter};
    future = widget.api.getCustomers();
    loadSavedFilters();
    loadSavedSort();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadSavedSort() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('customers_sort_mode');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => sortMode = saved);
    }
  }

  Future<void> loadSavedFilters() async {
    if (widget.initialFilter != 'all') {
      await saveFilters(filters);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('customers_filters');
    if (saved != null && saved.isNotEmpty && mounted) {
      final clean = saved.where((value) => value.trim().isNotEmpty).toSet();
      setState(() => filters = clean.isEmpty ? {'all'} : clean);
    }
  }

  Future<void> saveFilters(Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customers_filters', values.toList());
  }

  Future<void> setSortMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customers_sort_mode', value);
    if (mounted) setState(() => sortMode = value);
  }

  Set<String> nextFiltersFor(String value) {
    if (value == 'all') return {'all'};
    final next = Set<String>.from(filters)..remove('all');
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next.isEmpty ? {'all'} : next;
  }

  void selectFilter(String value) {
    final next = nextFiltersFor(value);
    setState(() => filters = next);
    saveFilters(next);
  }

  void reload() => setState(() => future = widget.api.getCustomers());

  Future<void> addCustomer() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormPage(api: widget.api)),
    );
    if (ok == true) reload();
  }

  bool matchesFilter(Map<String, dynamic> c, String value) {
    switch (value) {
      case 'active':
        return customerIsActive(c);
      case 'online':
        return customerIsOnline(c);
      case 'offline':
        return !customerIsOnline(c);
      case 'expired':
        return customerIsExpired(c);
      case 'soon':
        return customerExpiresSoon(c);
      case 'debt':
        return customerDebtValue(c) > 0;
      default:
        return true;
    }
  }

  int filterCount(List<Map<String, dynamic>> items, String value) =>
      items.where((c) => matchesFilter(c, value)).length;

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> items) {
    final q = query.trim().toLowerCase();
    final activeFilters = filters.where((value) => value != 'all').toList();
    final filtered = items.where((c) {
      final matchesQuery = q.isEmpty || normalizedSearchText(c).contains(q);
      final matchesSelectedFilters = activeFilters.isEmpty ||
          activeFilters.any((value) => matchesFilter(c, value));
      return matchesQuery && matchesSelectedFilters;
    }).toList();
    filtered.sort(compareCustomers);
    return filtered;
  }

  int compareCustomers(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aDays = customerRemainingDays(a) ?? 999999;
    final bDays = customerRemainingDays(b) ?? 999999;
    final aName = asText(a['name']).toLowerCase();
    final bName = asText(b['name']).toLowerCase();
    switch (sortMode) {
      case 'remaining_desc':
        return bDays.compareTo(aDays);
      case 'remaining_asc':
        return aDays.compareTo(bDays);
      case 'expiry_date':
        return (customerExpiryDateTime(a)?.millisecondsSinceEpoch ??
                9999999999999)
            .compareTo(
          customerExpiryDateTime(b)?.millisecondsSinceEpoch ?? 9999999999999,
        );
      case 'debt_high':
        return customerDebtValue(b).compareTo(customerDebtValue(a));
      case 'price_high':
        return asInt(b['price']).compareTo(asInt(a['price']));
      case 'notes_first':
        final an = asText(a['notes'], '').isNotEmpty ? 1 : 0;
        final bn = asText(b['notes'], '').isNotEmpty ? 1 : 0;
        final byNotes = bn.compareTo(an);
        if (byNotes != 0) return byNotes;
        return aName.compareTo(bName);
      case 'name':
      default:
        return aName.compareTo(bName);
    }
  }

  String sortLabel() {
    switch (sortMode) {
      case 'remaining_desc':
        return 'الأكثر أيامًا متبقية';
      case 'remaining_asc':
        return 'الأقل أيامًا متبقية';
      case 'expiry_date':
        return 'انتهاء الاشتراك الأقرب';
      case 'debt_high':
        return 'دين المشترك';
      case 'price_high':
        return 'سعر الاشتراك';
      case 'notes_first':
        return 'الملاحظات أولًا';
      case 'name':
      default:
        return 'الاسم';
    }
  }

  Future<void> chooseSort() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ترتيب المشتركين',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              sortTile('name', 'الاسم', Icons.sort_by_alpha_rounded),
              sortTile(
                'remaining_desc',
                'الأكثر أيامًا متبقية',
                Icons.trending_up_rounded,
              ),
              sortTile(
                'remaining_asc',
                'الأقل أيامًا متبقية',
                Icons.trending_down_rounded,
              ),
              sortTile(
                'expiry_date',
                'انتهاء الاشتراك الأقرب',
                Icons.event_busy_rounded,
              ),
              sortTile(
                'debt_high',
                'دين المشترك',
                Icons.account_balance_wallet_rounded,
              ),
              sortTile('price_high', 'سعر الاشتراك', Icons.payments_rounded),
              sortTile('notes_first', 'الملاحظات أولًا', Icons.notes_rounded),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await setSortMode(selected);
  }

  Widget sortTile(String value, String label, IconData icon) {
    final selected = sortMode == value;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: selected ? AppColors.primary : AppColors.muted,
        size: 21,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.text : AppColors.muted,
        ),
      ),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 20,
            )
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  String filterSheetLabel(String value) {
    switch (value) {
      case 'active':
        return 'فعال';
      case 'online':
        return 'المتصلين الحاليين';
      case 'offline':
        return 'غير المتصلين';
      case 'expired':
        return 'المنتهين';
      case 'soon':
        return 'قريب من الانتهاء';
      case 'debt':
        return 'عليهم دين';
      case 'all':
      default:
        return 'الكل';
    }
  }

  IconData filterSheetIcon(String value) {
    switch (value) {
      case 'active':
        return Icons.check_circle_outline_rounded;
      case 'online':
        return Icons.wifi_rounded;
      case 'offline':
        return Icons.wifi_off_rounded;
      case 'expired':
        return Icons.cancel_outlined;
      case 'soon':
        return Icons.warning_amber_rounded;
      case 'debt':
        return Icons.account_balance_wallet_outlined;
      case 'all':
      default:
        return Icons.explore_outlined;
    }
  }

  Color filterSheetColor(String value) {
    switch (value) {
      case 'active':
        return AppColors.green;
      case 'online':
        return AppColors.primary;
      case 'offline':
        return AppColors.red;
      case 'expired':
        return AppColors.red;
      case 'soon':
        return AppColors.warning;
      case 'debt':
        return AppColors.purple;
      case 'all':
      default:
        return AppColors.primary;
    }
  }

  List<String> selectedFilterValues() =>
      filters.where((value) => value != 'all').toList();

  String selectedFiltersLabel() {
    final selected = selectedFilterValues();
    if (selected.isEmpty) return filterSheetLabel('all');
    if (selected.length == 1) return filterSheetLabel(selected.first);
    return selected.map(filterSheetLabel).join('، ');
  }

  IconData selectedFiltersIcon() {
    final selected = selectedFilterValues();
    return selected.length == 1
        ? filterSheetIcon(selected.first)
        : Icons.filter_alt_rounded;
  }

  Color selectedFiltersColor() {
    final selected = selectedFilterValues();
    return selected.length == 1
        ? filterSheetColor(selected.first)
        : AppColors.primary;
  }

  Future<void> chooseFilter(List<Map<String, dynamic>> all) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: .50,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Text(
                    'فلترة المشتركين',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر القائمة. يتم التطبيق مباشرة بدون زر إضافي.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        filterSheetTile(
                          'all',
                          all.length,
                          onChanged: () {
                            selectFilter('all');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'active',
                          filterCount(all, 'active'),
                          onChanged: () {
                            selectFilter('active');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'online',
                          filterCount(all, 'online'),
                          onChanged: () {
                            selectFilter('online');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'offline',
                          filterCount(all, 'offline'),
                          onChanged: () {
                            selectFilter('offline');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'soon',
                          filterCount(all, 'soon'),
                          onChanged: () {
                            selectFilter('soon');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'expired',
                          filterCount(all, 'expired'),
                          onChanged: () {
                            selectFilter('expired');
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        filterSheetTile(
                          'debt',
                          filterCount(all, 'debt'),
                          onChanged: () {
                            selectFilter('debt');
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget filterSheetTile(String value, int count, {VoidCallback? onChanged}) {
    final selected = filters.contains(value);
    final color = filterSheetColor(value);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onChanged ?? () => selectFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.14) : AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color.withOpacity(.55) : AppColors.border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(.28)
                    : Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? color.withOpacity(.6)
                      : Colors.white.withOpacity(.20),
                ),
              ),
              alignment:
                  selected ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Text(
                    filterSheetLabel(value),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: selected ? AppColors.text : AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(filterSheetIcon(value), size: 22, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget filterChipPro(String value, String label, int count, IconData icon) {
    final selected = filters.contains(value);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => selectFilter(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(.20),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(.18)
                      : AppColors.cardSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final items = applyFilters(all);

        return PageFrame(
          title: 'المشتركين',
          subtitle:
              'آخر مزامنة تظهر من صفحة الساس — البحث والفلاتر محلية وسريعة',
          action: IconButton.filledTonal(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'تحديث',
          ),
          children: [
            TextField(
              controller: searchController,
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم، اليوزر، الهاتف، أو الباقة',
                prefixIcon: Icon(Icons.search_rounded, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              color: AppColors.cardSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => chooseFilter(all),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: selectedFiltersColor().withOpacity(
                                      .16,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    selectedFiltersIcon(),
                                    size: 18,
                                    color: selectedFiltersColor(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'الفلترة الحالية',
                                        style: TextStyle(
                                          color: AppColors.faint,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        selectedFiltersLabel(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSoft,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: chooseSort,
                        child: Container(
                          width: 54,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            size: 22,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الترتيب الحالي: ${sortLabel()}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!snapshot.hasData && !snapshot.hasError)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (snapshot.hasError)
              AppCard(
                child: Text(
                  'تعذر جلب المشتركين: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.red),
                ),
              ),
            if (snapshot.hasData && items.isEmpty)
              AppCard(
                child: Column(
                  children: const [
                    Icon(
                      Icons.search_off_rounded,
                      color: AppColors.muted,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'لا توجد نتائج مطابقة',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'غيّر الفلتر أو البحث الحالي.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            for (final customer in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CustomerCard(
                  api: widget.api,
                  customer: customer,
                  onChanged: reload,
                ),
              ),
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
  const CustomerCard({
    super.key,
    required this.api,
    required this.customer,
    required this.onChanged,
  });

  Future<void> details(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailsPage(api: api, customer: customer),
      ),
    );
    if (ok == true) onChanged();
  }

  Future<void> pay(BuildContext context) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(api: api, customer: customer),
      ),
    );
    if (result != null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final days = customerRemainingDays(customer);
    final online = customerIsOnline(customer);
    final badgeColor = remainingBadgeColor(days);
    final username = asText(customer['sasUsername'], asText(customer['phone']));
    final packageName = asText(customer['package']);
    final ip = asText(customer['sasIp'], 'غير متوفر');
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => details(context),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniIcon(
                  Icons.person_rounded,
                  color: online ? AppColors.green : AppColors.red,
                  box: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asText(customer['name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.2,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                RemainingBadge(
                  days: days,
                  color: badgeColor,
                  customText: remainingDetailedText(customer),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OnlinePill(online: online),
                SmallTag(
                  icon: Icons.data_usage_rounded,
                  label: compactTrafficLabel(customer),
                  color: AppColors.primary,
                ),
                if (customerDebtValue(customer) > 0)
                  SmallTag(
                    icon: Icons.account_balance_wallet_rounded,
                    label: money(customerDebtValue(customer)),
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniInfo(
                          'انتهاء الاشتراك',
                          dateLabel(customer['expiresAt']),
                        ),
                      ),
                      Expanded(
                        child: _MiniInfo(
                          'آخر اتصال',
                          asText(customer['sasLastOnline'], 'غير متوفر'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _MiniInfo('IP', ip)),
                      Expanded(
                        child: _MiniInfo(
                          'المدير',
                          asText(customer['sasParentUsername'], 'غير متوفر'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => pay(context),
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text('تسديد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RemainingBadge extends StatelessWidget {
  final int? days;
  final Color color;
  final String? customText;
  final bool compact;
  const RemainingBadge({
    super.key,
    required this.days,
    required this.color,
    this.customText,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 84 : 92),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: color.withOpacity(.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            days == null
                ? Icons.help_outline_rounded
                : (days! <= 0 ? Icons.block_rounded : Icons.timelapse_rounded),
            size: compact ? 14 : 15,
            color: color,
          ),
          SizedBox(height: compact ? 2 : 3),
          Text(
            customText ?? remainingBadgeText(days),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10.8 : 11.5,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class OnlinePill extends StatelessWidget {
  final bool online;
  const OnlinePill({super.key, required this.online});
  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'متصل' : 'غير متصل',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SmallTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const SmallTag({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _MiniInfo extends StatelessWidget {
  final String label, value;
  const _MiniInfo(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.faint,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class CustomerDetailsPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  const CustomerDetailsPage({
    super.key,
    required this.api,
    required this.customer,
  });

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  late Map<String, dynamic> customer;
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    customer = Map<String, dynamic>.from(widget.customer);
  }

  Future<void> edit(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(api: widget.api, customer: customer),
      ),
    );
    if (ok == true) {
      await reloadCustomer();
      markDirty();
    }
  }

  Future<void> pay(BuildContext context) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(api: widget.api, customer: customer),
      ),
    );
    if (result != null) {
      applyCustomerUpdate(result);
      markDirty();
    }
  }

  void markDirty() {
    if (mounted) setState(() => dirty = true);
  }

  void applyCustomerUpdate(Map<String, dynamic> updated) {
    if (!mounted) return;
    setState(() {
      customer = {...customer, ...updated};
      dirty = true;
    });
  }

  Future<void> reloadCustomer() async {
    try {
      final data = await widget.api.getCustomer(customer['id']);
      final updated = data['customer'];
      if (updated is Map<String, dynamic>) {
        applyCustomerUpdate(updated);
      }
    } catch (_) {}
  }

  Future<void> addDebt() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إضافة دين',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'أدخل المبلغ وسيُضاف فورًا على دين المشترك.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة اختيارية',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'amount': asInt(amountController.text),
                  'note': noteController.text.trim(),
                }),
                child: const Text('حفظ الدين'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final amount = asInt(result['amount']);
    if (amount <= 0) return;
    final mergedNotes = mergeNotes(
      asText(customer['notes'], ''),
      result['note'],
    );
    final response = await widget.api.updateCustomer(customer['id'], {
      'debt': asInt(customer['debt']) + amount,
      'notes': mergedNotes,
    });
    if (response['ok'] == true) {
      final updated = response['customer'];
      if (updated is Map<String, dynamic>) applyCustomerUpdate(updated);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تمت إضافة الدين مباشرة')));
    }
  }

  Future<void> editNotes() async {
    final controller = TextEditingController(
      text: asText(customer['notes'], ''),
    );
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'اكتب الملاحظات',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('حفظ الملاحظات'),
              ),
            ),
          ],
        ),
      ),
    );
    if (value == null) return;
    final response = await widget.api.updateCustomer(customer['id'], {
      'notes': value,
    });
    if (response['ok'] == true) {
      final updated = response['customer'];
      if (updated is Map<String, dynamic>) applyCustomerUpdate(updated);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظات')));
    }
  }

  String mergeNotes(String current, dynamic extra) {
    final next = asText(extra, '');
    if (next == '—' || next.isEmpty) return current;
    if (current.isEmpty || current == '—') return next;
    return '$current\n• $next';
  }

  void showActionMessage(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('مفهوم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إجراءات المشترك',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              actionTile(
                'change_package',
                'تغيير نوع الاشتراك',
                Icons.speed_rounded,
              ),
              actionTile('extend', 'تمديد', Icons.more_time_rounded),
              actionTile(
                'rename',
                'تعديل الاسم',
                Icons.drive_file_rename_outline_rounded,
              ),
              actionTile('restrict', 'تقييد المستخدم', Icons.lock_rounded),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'rename') return edit(context);
    if (selected == 'change_package') {
      showActionMessage(
        'تغيير نوع الاشتراك',
        'سيتم جلب أنواع الاشتراكات من SAS لاحقًا. لا يمكن تغيير نوع الاشتراك إلا بعد انتهاء الاشتراك الحالي، وبعدها يستطيع المستخدم التجديد على النوع الجديد.',
      );
    } else if (selected == 'extend') {
      showActionMessage(
        'تمديد الاشتراك',
        'التمديد يحتاج ربطًا مباشرًا مع أوامر SAS حتى لا يحصل اختلاف بين Nodrix واللوحة. سنناقشه كمرحلة مستقلة.',
      );
    } else if (selected == 'restrict') {
      showActionMessage(
        'تقييد المستخدم',
        'التقييد يجب أن ينفذ داخل SAS فعليًا على اليوزر، لذلك سيُضاف بعد تثبيت أوامر التعديل على حسابات SAS.',
      );
    }
  }

  Widget actionTile(String value, String label, IconData icon) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.primary, size: 21),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: () => Navigator.pop(context, value),
      );

  Future<bool> onWillPop() async {
    Navigator.pop(context, dirty);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final online = customerIsOnline(customer);
    final stateColor = online ? AppColors.green : AppColors.red;
    final debt = customerDebtValue(customer);
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المشترك'),
          leading: IconButton(
            onPressed: openMenu,
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'إجراءات',
          ),
          actions: [
            IconButton(
              onPressed: () => edit(context),
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'تعديل',
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, dirty),
              icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: 'رجوع',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            AppCard(
              color: AppColors.cardSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MiniIcon(
                        Icons.person_rounded,
                        color: stateColor,
                        box: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          asText(customer['name']),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OnlinePill(online: online),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (debt > 0 ? AppColors.warning : AppColors.green)
                          .withOpacity(.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: (debt > 0 ? AppColors.warning : AppColors.green)
                            .withOpacity(.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الدين',
                          style: TextStyle(
                            color:
                                debt > 0 ? AppColors.warning : AppColors.green,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money(debt),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              color: AppColors.cardSoft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    QuickActionButton(
                      icon: Icons.payments_rounded,
                      label: 'تسديد',
                      onTap: () => pay(context),
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 14),
                    QuickActionButton(
                      icon: Icons.add_card_rounded,
                      label: 'إضافة دين',
                      onTap: addDebt,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 14),
                    QuickActionButton(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      onTap: editNotes,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 14),
                    QuickActionButton(
                      icon: Icons.history_rounded,
                      label: 'السجل',
                      onTap: () => showActionMessage(
                        'السجل',
                        'يمكن إضافة سجل عمليات المشترك لاحقًا في مرحلة مستقلة.',
                      ),
                      color: AppColors.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  InfoLine(
                    'الحالة',
                    online ? 'متصل' : 'غير متصل',
                    Icons.wifi_rounded,
                    valueColor: stateColor,
                  ),
                  InfoLine(
                    'الأيام المتبقية',
                    remainingDetailedText(customer),
                    Icons.timelapse_rounded,
                    valueColor: remainingBadgeColor(
                      customerRemainingDays(customer),
                    ),
                  ),
                  InfoLine(
                    'سعر الاشتراك',
                    money(customer['price']),
                    Icons.payments_rounded,
                  ),
                  InfoLine(
                    'نوع الاشتراك',
                    asText(customer['package']),
                    Icons.speed_rounded,
                  ),
                  InfoLine(
                    'المدير',
                    asText(customer['sasParentUsername'], 'غير متوفر'),
                    Icons.admin_panel_settings_rounded,
                  ),
                  InfoLine(
                    'اليوزر',
                    asText(customer['sasUsername']),
                    Icons.alternate_email_rounded,
                  ),
                  InfoLine(
                    'رقم الهاتف',
                    asText(
                      customer['phone'],
                      asText(customer['sasPhone'], 'غير متوفر'),
                    ),
                    Icons.phone_rounded,
                  ),
                  InfoLine(
                    'تاريخ انتهاء الاشتراك',
                    dateLabel(customer['expiresAt']),
                    Icons.event_busy_rounded,
                  ),
                  InfoLine(
                    'IP',
                    asText(customer['sasIp'], 'غير متوفر'),
                    Icons.lan_rounded,
                  ),
                  InfoLine(
                    'البرج',
                    asText(customer['tower']),
                    Icons.cell_tower_rounded,
                  ),
                  InfoLine(
                    'السكتر',
                    asText(customer['sector']),
                    Icons.settings_input_antenna_rounded,
                  ),
                  InfoLine(
                    'ملاحظات',
                    asText(customer['notes']),
                    Icons.notes_rounded,
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(child: Icon(icon, size: 30, color: color)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool last;
  final Color? valueColor;
  const InfoLine(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.last = false,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
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
  late final TextEditingController name,
      phone,
      package,
      speed,
      price,
      tower,
      sector,
      address,
      notes,
      debt;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب اسم المشترك')));
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
      final result = editing
          ? await widget.api.updateCustomer(widget.customer!['id'], data)
          : await widget.api.addCustomer(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asText(result['message'], 'تم الحفظ'))),
      );
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        textDirection: type == TextInputType.number
            ? TextDirection.ltr
            : TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل مشترك' : 'إضافة مشترك')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppCard(
            child: Column(
              children: [
                input('اسم المشترك', name, Icons.person_rounded),
                input(
                  'الهاتف',
                  phone,
                  Icons.phone_rounded,
                  type: TextInputType.phone,
                ),
                input('الباقة', package, Icons.speed_rounded),
                input('السرعة', speed, Icons.bolt_rounded),
                input(
                  'السعر',
                  price,
                  Icons.payments_rounded,
                  type: TextInputType.number,
                ),
                input(
                  'الدين',
                  debt,
                  Icons.account_balance_wallet_rounded,
                  type: TextInputType.number,
                ),
                input('البرج', tower, Icons.cell_tower_rounded),
                input('السكتر', sector, Icons.settings_input_antenna_rounded),
                AppCard(
                  color: AppColors.panel,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'التواريخ والباقات الأساسية ستأتي من الساس عند المزامنة. لا تدخلها يدويًا.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                input('العنوان', address, Icons.location_on_rounded),
                input('ملاحظات', notes, Icons.notes_rounded, maxLines: 2),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    saving
                        ? 'جاري الحفظ...'
                        : editing
                            ? 'حفظ التعديل'
                            : 'إضافة المشترك',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      final result = await widget.api.addPayment(widget.customer['id'], {
        'amount': asInt(amount.text),
        'note': note.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asText(result['message'], 'تمت العملية'))),
      );
      if (result['ok'] == true)
        Navigator.pop(context, result['customer'] ?? {'updated': true});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(
    String label,
    TextEditingController c,
    IconData icon, {
    TextInputType? type,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          textDirection: type == TextInputType.number
              ? TextDirection.ltr
              : TextDirection.rtl,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 18),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسديد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppCard(
            child: Column(
              children: [
                input(
                  'المبلغ',
                  amount,
                  Icons.payments_rounded,
                  type: TextInputType.number,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'تاريخ الدفع يحسب تلقائيًا. تاريخ الانتهاء يبقى من الساس ولا يكتب يدويًا.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
                input('ملاحظة', note, Icons.notes_rounded),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('حفظ التسديد'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final ApiService api;
  final void Function(String filter) onOpenFilter;
  const DashboardPage({
    super.key,
    required this.api,
    required this.onOpenFilter,
  });

  void openIncomeMonth(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MonthlyIncomePage(api: api)),
    );
  }

  void openCustomerList(
    BuildContext context,
    String title,
    bool Function(Map<String, dynamic>) predicate,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardCustomerListPage(
          api: api,
          title: title,
          predicate: predicate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([api.getDashboard(), api.getCustomers()]),
      builder: (context, snapshot) {
        final data = snapshot.data?[0] as Map<String, dynamic>? ?? {};
        final customers =
            (snapshot.data?[1] as List<Map<String, dynamic>>?) ?? [];
        final activeCustomers = customers.where(customerIsActive).toList();
        final soonCustomers = customers.where(customerExpiresSoon).toList();
        final expiredCustomers = customers.where(customerIsExpired).toList();
        return PageFrame(
          title: 'الرئيسية',
          subtitle: 'نظرة مختصرة على العمل اليومي',
          children: [
            if (!snapshot.hasData && !snapshot.hasError)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (snapshot.hasError)
              AppCard(
                child: Text(
                  'خطأ: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.red),
                ),
              ),
            if (snapshot.hasData) ...[
              AppCard(
                color: AppColors.cardSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const MiniIcon(
                          Icons.stacked_bar_chart_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ملخص الحسابات',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MetricLine(
                      'عدد المشتركين',
                      '${customers.length}',
                    ),
                    MetricLine('الدين الكلي', money(data['totalDebt'] ?? 0)),
                    MetricLine(
                      'دخل اليوم',
                      money(data['incomeToday'] ?? 0),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  StatCard(
                    'فعال',
                    '${activeCustomers.length}',
                    Icons.check_rounded,
                    AppColors.green,
                    onTap: () => openCustomerList(
                      context,
                      'المشتركون الفعالون',
                      customerIsActive,
                    ),
                  ),
                  StatCard(
                    'قريب الانتهاء',
                    '${soonCustomers.length}',
                    Icons.priority_high_rounded,
                    AppColors.warning,
                    onTap: () => openCustomerList(
                      context,
                      'قريب الانتهاء',
                      customerExpiresSoon,
                    ),
                  ),
                  StatCard(
                    'منتهي',
                    '${expiredCustomers.length}',
                    Icons.close_rounded,
                    AppColors.red,
                    onTap: () => openCustomerList(
                      context,
                      'المشتركون المنتهون',
                      customerIsExpired,
                    ),
                  ),
                  StatCard(
                    'دخل الشهر',
                    money(data['incomeMonth'] ?? 0),
                    Icons.payments_rounded,
                    AppColors.primary,
                    onTap: () => openIncomeMonth(context),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class DashboardCustomerListPage extends StatefulWidget {
  final ApiService api;
  final String title;
  final bool Function(Map<String, dynamic>) predicate;
  const DashboardCustomerListPage({
    super.key,
    required this.api,
    required this.title,
    required this.predicate,
  });

  @override
  State<DashboardCustomerListPage> createState() =>
      _DashboardCustomerListPageState();
}

class _DashboardCustomerListPageState extends State<DashboardCustomerListPage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.getCustomers();
  }

  void reload() => setState(() => future = widget.api.getCustomers());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          final items = (snapshot.data ?? []).where(widget.predicate).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              if (!snapshot.hasData && !snapshot.hasError)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (snapshot.hasError)
                AppCard(
                  child: Text(
                    'تعذر جلب القائمة: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              if (snapshot.hasData && items.isEmpty)
                const AppCard(
                  child: Text(
                    'لا توجد نتائج مطابقة الآن.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final customer in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CustomerCard(
                    api: widget.api,
                    customer: customer,
                    onChanged: reload,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MonthlyIncomePage extends StatelessWidget {
  final ApiService api;
  const MonthlyIncomePage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دخل الشهر')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: api.getIncomeMonthDays(),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              if (!snapshot.hasData && !snapshot.hasError)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (snapshot.hasError)
                AppCard(
                  child: Text(
                    'تعذر جلب دخل الشهر: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              if (snapshot.hasData && rows.isEmpty)
                const AppCard(
                  child: Text(
                    'لا يوجد دخل مسجل هذا الشهر.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        MiniIcon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          box: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            asText(row['date']),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          money(row['total']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      );
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard(
    this.title,
    this.value,
    this.icon,
    this.color, {
    super.key,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MiniIcon(icon, color: color, box: 32),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class DevicesPage extends StatefulWidget {
  final ApiService api;
  const DevicesPage({super.key, required this.api});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String selectedDeviceTool = 'sector';
  String selectedPingTarget = 'google';
  int refreshToken = 0;

  final List<Map<String, dynamic>> pingTargets = const [
    {
      'id': 'google',
      'label': 'Google',
      'host': '8.8.8.8',
      'icon': Icons.search_rounded,
    },
    {
      'id': 'youtube',
      'label': 'YouTube',
      'host': 'youtube.com',
      'icon': Icons.play_circle_rounded,
    },
    {
      'id': 'whatsapp',
      'label': 'WhatsApp',
      'host': 'whatsapp.com',
      'icon': Icons.chat_rounded,
    },
    {
      'id': 'snapchat',
      'label': 'Snap',
      'host': 'snapchat.com',
      'icon': Icons.camera_alt_rounded,
    },
    {
      'id': 'facebook',
      'label': 'Facebook',
      'host': 'facebook.com',
      'icon': Icons.groups_rounded,
    },
    {
      'id': 'x',
      'label': 'X',
      'host': 'x.com',
      'icon': Icons.alternate_email_rounded,
    },
    {
      'id': 'dns',
      'label': '8.8.8.8',
      'host': '8.8.8.8',
      'icon': Icons.dns_rounded,
    },
  ];

  Future<void> addDevice() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NetworkDeviceFormPage(
          api: widget.api,
          initialRole:
              selectedDeviceTool == 'ping' ? 'sector' : selectedDeviceTool,
        ),
      ),
    );
    if (ok == true && mounted) setState(() => refreshToken++);
  }

  Future<void> showNetworkList(
    String title,
    IconData icon,
    Future<List<dynamic>> Function() loader,
  ) async {
    final futureRows = loader();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MiniIcon(icon, color: AppColors.primary, box: 38),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: futureRows,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData && !snapshot.hasError)
                        return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError)
                        return Text(
                          'تعذر الجلب: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.red),
                        );
                      final rows = snapshot.data ?? [];
                      if (rows.isEmpty)
                        return const Center(
                          child: Text(
                            'لا توجد بيانات متاحة الآن.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        );
                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          final map =
                              row is Map ? row : {'name': row.toString()};
                          final name = asText(
                            map['name'] ?? map['title'] ?? map['username'],
                            'Device',
                          );
                          final subtitle = asText(
                            map['status'] ??
                                map['ip'] ??
                                map['ipAddress'] ??
                                map['address'],
                            'Ready',
                          );
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showPingTools() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .45,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.network_ping_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Ping وأدوات الشبكة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                toolListTile(
                  Icons.public_rounded,
                  'Ping للـ IP',
                  'اختبار اتصال IP المشترك أو جهاز في الشبكة',
                ),
                const SizedBox(height: 8),
                toolListTile(
                  Icons.router_rounded,
                  'فحص الراوتر',
                  'قائمة أدوات فحص خفيفة ستربط لاحقًا بالأجهزة',
                ),
                const SizedBox(height: 8),
                toolListTile(
                  Icons.cell_tower_rounded,
                  'فحص السكتر',
                  'اختبار حالة السكتر أو اللنك المرتبط به',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget toolListTile(
    IconData icon,
    String title,
    String subtitle,
  ) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget networkToolButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );

  Widget pingPanel() {
    final selected = pingTargets.firstWhere(
      (target) => target['id'] == selectedPingTarget,
      orElse: () => pingTargets.first,
    );
    return AppCard(
      color: AppColors.cardSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              MiniIcon(
                Icons.network_ping_rounded,
                color: AppColors.primary,
                box: 34,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ping',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final target in pingTargets)
                ChoiceChip(
                  selected: selectedPingTarget == target['id'],
                  onSelected: (_) => setState(
                    () => selectedPingTarget = target['id'] as String,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(target['icon'] as IconData, size: 16),
                      const SizedBox(width: 6),
                      Text(target['label'] as String),
                    ],
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.panel,
                  side: BorderSide(
                    color: selectedPingTarget == target['id']
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: selectedPingTarget == target['id']
                        ? Colors.white
                        : AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected['host'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'سيتم ربط اختبار ${selected['label']} فعليًا في خطوة أدوات الشبكة.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('بدء الاختبار'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'الأجهزة',
      subtitle: 'عرض أولي للأجهزة واللنكات',
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          color: AppColors.cardSoft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                networkToolButton(
                  'Sector',
                  Icons.settings_input_antenna_rounded,
                  () => setState(() => selectedDeviceTool = 'sector'),
                  selected: selectedDeviceTool == 'sector',
                ),
                const SizedBox(width: 10),
                networkToolButton(
                  'Link',
                  Icons.link_rounded,
                  () => setState(() => selectedDeviceTool = 'link'),
                  selected: selectedDeviceTool == 'link',
                ),
                const SizedBox(width: 10),
                networkToolButton(
                  'Switch',
                  Icons.settings_ethernet_rounded,
                  () => setState(() => selectedDeviceTool = 'switch'),
                  selected: selectedDeviceTool == 'switch',
                ),
                const SizedBox(width: 10),
                networkToolButton(
                  'Ping',
                  Icons.network_ping_rounded,
                  () => setState(() => selectedDeviceTool = 'ping'),
                  selected: selectedDeviceTool == 'ping',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (selectedDeviceTool != 'ping')
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: addDevice,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ربط جهاز'),
            ),
          ),
        if (selectedDeviceTool != 'ping') const SizedBox(height: 12),
        if (selectedDeviceTool != 'ping')
          FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('$selectedDeviceTool-$refreshToken'),
            future: localNetworkDevices.getDevices(role: selectedDeviceTool),
            builder: (context, snapshot) => NetworkDeviceSection(
              api: widget.api,
              title: selectedDeviceTool == 'sector'
                  ? 'السكاتر / Sector'
                  : selectedDeviceTool == 'link'
                      ? 'اللنكات / Link'
                      : 'السويتجات / Switch',
              items: snapshot.data ?? [],
              loading: !snapshot.hasData && !snapshot.hasError,
              onChanged: () => setState(() => refreshToken++),
            ),
          ),
        if (selectedDeviceTool == 'ping') pingPanel(),
      ],
    );
  }
}

class DeviceSection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool loading;
  const DeviceSection({
    super.key,
    required this.title,
    required this.items,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (!loading && items.isEmpty)
            const Text(
              'لا توجد بيانات حاليًا',
              style: TextStyle(color: AppColors.muted),
            ),
          for (final raw in items)
            DeviceRow(item: Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
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
      child: Row(
        children: [
          MiniIcon(Icons.router_rounded, color: statusColor(status), box: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asText(item['name']),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  asText(item['ip'] ?? item['ipAddress'], 'IP غير محدد'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusPill(status),
        ],
      ),
    );
  }
}

class NetworkDeviceSection extends StatelessWidget {
  final ApiService api;
  final String title;
  final List<Map<String, dynamic>> items;
  final bool loading;
  final VoidCallback onChanged;
  const NetworkDeviceSection({
    super.key,
    required this.api,
    required this.title,
    required this.items,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (!loading && items.isEmpty)
          const Text('لا توجد أجهزة مرتبطة حاليًا',
              style: TextStyle(color: AppColors.muted)),
        if (!loading && items.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) async {
              await localNetworkDevices.reorderDevices(
                role: asText(items.first['role'], ''),
                oldIndex: oldIndex,
                newIndex: newIndex,
              );
              onChanged();
            },
            itemBuilder: (context, index) => NetworkDeviceRow(
              key: ValueKey(asText(items[index]['id'], '$index')),
              api: api,
              item: items[index],
              index: index,
              onChanged: onChanged,
            ),
          ),
      ]),
    );
  }
}

class NetworkDeviceRow extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onChanged;
  const NetworkDeviceRow({
    super.key,
    required this.api,
    required this.item,
    required this.index,
    required this.onChanged,
  });

  @override
  State<NetworkDeviceRow> createState() => _NetworkDeviceRowState();
}

class _NetworkDeviceRowState extends State<NetworkDeviceRow> {
  bool busy = false;
  final ubntLocal = UbntLocalService();
  final mikrotikLocal = MikrotikLocalService();
  Map<String, dynamic>? liveItem;

  @override
  void initState() {
    super.initState();
    checkLiveStatus();
  }

  Future<void> checkLiveStatus() async {
    final id = asText(widget.item['id']);
    final vendor = asText(widget.item['vendor'], '').toLowerCase();
    final username =
        await secureStorage.read(key: 'networkDevice.$id.username') ??
            asText(widget.item['username'], '');
    final password =
        await secureStorage.read(key: 'networkDevice.$id.password') ?? '';
    if (username.isEmpty && password.isEmpty) return;
    Map<String, dynamic>? result;
    if (vendor.contains('ubiquiti') || vendor.contains('ubnt')) {
      result = await ubntLocal.readLive(
        device: widget.item,
        username: username,
        password: password,
        includeClients: false,
      );
    } else if (vendor.contains('mikrotik')) {
      result = await mikrotikLocal.readLive(
        device: widget.item,
        username: username,
        password: password,
        includeClients: false,
      );
    }
    if (!mounted || result == null) return;
    final device = Map<String, dynamic>.from((result['device'] as Map?) ?? {});
    final stats = Map<String, dynamic>.from((result['stats'] as Map?) ?? {});
    final updated = {
      ...widget.item,
      'status': asText(device['status'], 'offline'),
      'lastError': asText(device['lastError'] ?? result['message'], ''),
      'model': asText(stats['model'], asText(widget.item['model'], '')),
      'lastSeenAt': DateTime.now().toIso8601String(),
    };
    setState(() => liveItem = updated);
    await localNetworkDevices.updateDevice(id, updated);
  }

  Future<void> editName() async {
    final controller = TextEditingController(text: asText(widget.item['name']));
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل اسم الجهاز'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم الجهاز'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await localNetworkDevices.updateDeviceName(
        asText(widget.item['id']), value);
    widget.onChanged();
  }

  Future<void> deleteDevice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الجهاز'),
        content: Text(
          'هل تريد حذف ${asText(widget.item['name'])} من قائمة الأجهزة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await localNetworkDevices.deleteDevice(asText(widget.item['id']));
    widget.onChanged();
  }

  Future<void> rebootDevice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تشغيل السكتر'),
        content: Text(
          'سيتم إرسال أمر reboot إلى ${asText(widget.item['name'])}. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      final id = asText(widget.item['id']);
      final username =
          await secureStorage.read(key: 'networkDevice.$id.username') ??
              asText(widget.item['username'], '');
      final password =
          await secureStorage.read(key: 'networkDevice.$id.password') ?? '';
      final vendor = asText(widget.item['vendor'], '').toLowerCase();
      final result = vendor.contains('mikrotik')
          ? await mikrotikLocal.reboot(
              device: widget.item,
              username: username,
              password: password,
            )
          : await ubntLocal.reboot(
              device: widget.item,
              username: username,
              password: password,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asText(result['message'], 'تم تنفيذ الأمر'))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = liveItem ?? widget.item;
    final status =
        asText(item['status'], 'offline') == 'online' ? 'online' : 'offline';
    final model = asText(item['model'], '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NetworkDeviceDetailsPage(
                api: widget.api,
                device: item,
              ),
            ),
          );
          widget.onChanged();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            RadioDeviceBadge(model: model, size: 62),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            asText(item['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        StatusPill(status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${asText(item['vendor'], 'vendor')} - ${asText(item['tower'], 'بدون برج')} - ${asText(item['ip'], 'IP غير محدد')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _rowAction(Icons.restart_alt_rounded, rebootDevice,
                            enabled: !busy),
                        _rowAction(Icons.edit_rounded, editName),
                        _rowAction(Icons.delete_outline_rounded, deleteDevice,
                            color: AppColors.red),
                        const Spacer(),
                        ReorderableDelayedDragStartListener(
                          index: widget.index,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.drag_handle_rounded,
                                color: AppColors.muted, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }

  Widget _rowAction(
    IconData icon,
    VoidCallback onTap, {
    Color color = AppColors.primary,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: enabled ? color : AppColors.faint),
      ),
    );
  }
}

class NetworkDeviceFormPage extends StatefulWidget {
  final ApiService api;
  final String initialRole;
  const NetworkDeviceFormPage({
    super.key,
    required this.api,
    required this.initialRole,
  });

  @override
  State<NetworkDeviceFormPage> createState() => _NetworkDeviceFormPageState();
}

class _NetworkDeviceFormPageState extends State<NetworkDeviceFormPage> {
  late String role;
  String vendor = 'ubiquiti';
  final name = TextEditingController();
  final tower = TextEditingController();
  final ip = TextEditingController();
  final port = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    role = widget.initialRole;
  }

  @override
  void dispose() {
    name.dispose();
    tower.dispose();
    ip.dispose();
    port.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final result = await localNetworkDevices.addDevice({
        'name': name.text.trim(),
        'role': role,
        'vendor': vendor,
        'tower': tower.text.trim(),
        'ip': ip.text.trim(),
        'port': port.text.trim(),
        'username': username.text.trim(),
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asText(result['message'], 'تم الحفظ'))),
      );
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(String label, TextEditingController controller, IconData icon,
      {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ربط جهاز')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppCard(
            child: Column(children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sector', label: Text('Sector')),
                  ButtonSegment(value: 'link', label: Text('Link')),
                  ButtonSegment(value: 'switch', label: Text('Switch')),
                ],
                selected: {role},
                onSelectionChanged: (value) =>
                    setState(() => role = value.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vendor,
                decoration: const InputDecoration(
                    labelText: 'الشركة',
                    prefixIcon: Icon(Icons.factory_rounded)),
                items: const [
                  DropdownMenuItem(value: 'ubiquiti', child: Text('Ubiquiti')),
                  DropdownMenuItem(value: 'mikrotik', child: Text('MikroTik')),
                  DropdownMenuItem(value: 'mimosa', child: Text('Mimosa')),
                  DropdownMenuItem(value: 'cisco', child: Text('Cisco')),
                  DropdownMenuItem(value: 'ruijie', child: Text('Ruijie')),
                ],
                onChanged: (value) =>
                    setState(() => vendor = value ?? 'ubiquiti'),
              ),
              const SizedBox(height: 12),
              field('اسم الجهاز', name, Icons.router_rounded),
              field('برج الإنترنت', tower, Icons.cell_tower_rounded),
              field('IP الجهاز', ip, Icons.lan_rounded),
              field('Port اختياري', port, Icons.settings_ethernet_rounded),
              field('Username', username, Icons.person_rounded),
              field('Password', password, Icons.lock_rounded, secret: true),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(saving ? 'جاري الربط...' : 'ربط الجهاز'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class NetworkDeviceDetailsPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> device;
  const NetworkDeviceDetailsPage({
    super.key,
    required this.api,
    required this.device,
  });

  @override
  State<NetworkDeviceDetailsPage> createState() =>
      _NetworkDeviceDetailsPageState();
}

class RadioDeviceBadge extends StatelessWidget {
  final String model;
  final double size;

  const RadioDeviceBadge({
    super.key,
    this.model = '',
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final label = model.trim().isEmpty ? 'UBNT' : model.trim().split(' ').first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(.22),
            AppColors.panel,
          ],
        ),
        border: Border.all(color: AppColors.primary.withOpacity(.28)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * .16,
            top: size * .14,
            child: Container(
              width: size * .34,
              height: size * .58,
              decoration: BoxDecoration(
                color: AppColors.text.withOpacity(.92),
                borderRadius: BorderRadius.circular(size * .07),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: size * .09,
                    height: 3,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(.75),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * .14,
            bottom: size * .18,
            child: Icon(
              Icons.settings_input_antenna_rounded,
              color: AppColors.primary,
              size: size * .42,
            ),
          ),
          Positioned(
            left: size * .12,
            top: size * .14,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text.withOpacity(.86),
                fontSize: size * .11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NanoDeviceBadge extends StatelessWidget {
  final String model;
  final double size;

  const NanoDeviceBadge({
    super.key,
    this.model = '',
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.text.withOpacity(.96),
                  AppColors.text.withOpacity(.66),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: size * .42,
            height: size * .42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: AppColors.primary,
              size: size * .26,
            ),
          ),
          Positioned(
            bottom: 5,
            child: Container(
              constraints: BoxConstraints(maxWidth: size * .82),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.panel.withOpacity(.92),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                model.trim().isEmpty ? 'Nano' : model.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkDeviceDetailsPageState extends State<NetworkDeviceDetailsPage> {
  final ubntLocal = UbntLocalService();
  final mikrotikLocal = MikrotikLocalService();
  Timer? timer;
  Map<String, dynamic>? data;
  bool loading = true;
  int pollCount = 0;

  @override
  void initState() {
    super.initState();
    load();
    timer =
        Timer.periodic(const Duration(seconds: 2), (_) => load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final includeClients = !silent || pollCount % 5 == 0;
      final result = await readDeviceLive(includeClients: includeClients);
      pollCount++;
      await persistLiveStatus(result);
      if (!includeClients && data != null) {
        result['deviceClients'] = data?['deviceClients'] ?? const [];
        final currentStats =
            Map<String, dynamic>.from((result['stats'] as Map?) ?? {});
        final previousStats =
            Map<String, dynamic>.from((data?['stats'] as Map?) ?? {});
        result['stats'] = {
          ...currentStats,
          'clients': previousStats['clients'] ?? currentStats['clients'],
        };
      }
      if (mounted) setState(() => data = result);
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> persistLiveStatus(Map<String, dynamic> result) async {
    final device = Map<String, dynamic>.from((result['device'] as Map?) ?? {});
    final stats = Map<String, dynamic>.from((result['stats'] as Map?) ?? {});
    final id = asText(device['id'], asText(widget.device['id'], ''));
    if (id.isEmpty) return;
    await localNetworkDevices.updateDevice(id, {
      'status': asText(device['status'], 'offline'),
      'lastError': asText(device['lastError'] ?? result['message'], ''),
      'model': asText(stats['model'], asText(device['model'], '')),
      'lastSeenAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> readDeviceLive(
      {bool includeClients = true}) async {
    final vendor = asText(widget.device['vendor'], '').toLowerCase();
    final deviceId = asText(widget.device['id'], '');
    if (vendor.contains('ubiquiti') || vendor.contains('ubnt')) {
      final localUsername =
          await secureStorage.read(key: 'networkDevice.$deviceId.username') ??
              asText(widget.device['username'], '');
      final localPassword =
          await secureStorage.read(key: 'networkDevice.$deviceId.password') ??
              '';
      if (localUsername.isNotEmpty || localPassword.isNotEmpty) {
        return ubntLocal.readLive(
          device: widget.device,
          username: localUsername,
          password: localPassword,
          includeClients: includeClients,
        );
      }
    }
    if (vendor.contains('mikrotik')) {
      final localUsername =
          await secureStorage.read(key: 'networkDevice.$deviceId.username') ??
              asText(widget.device['username'], '');
      final localPassword =
          await secureStorage.read(key: 'networkDevice.$deviceId.password') ??
              '';
      if (localUsername.isNotEmpty || localPassword.isNotEmpty) {
        return mikrotikLocal.readLive(
          device: widget.device,
          username: localUsername,
          password: localPassword,
          includeClients: includeClients,
        );
      }
    }
    return {
      'ok': true,
      'message': 'هذا النوع لم يفعّل له قارئ محلي بعد',
      'device': {
        ...widget.device,
        'status': 'configured',
      },
      'stats': {
        'connected': false,
        'clients': 0,
        'sampledAt': DateTime.now().toIso8601String(),
      },
      'deviceClients': const [],
      'customers': const [],
    };
  }

  Future<void> openIp(String ip) async {
    final value = ip.trim();
    if (value.isEmpty) return;
    final uri = Uri.parse('http://$value');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح IP، تم نسخه للحافظة')),
        );
      }
    }
  }

  Future<void> openClientsPage(
    Map<String, dynamic> device,
    List<Map<String, dynamic>> clients,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NetworkDeviceClientsPage(
          device: device,
          clients: clients,
          onOpenIp: openIp,
        ),
      ),
    );
  }

  Widget metric(String glyph, String label, String value, String unit,
      {Color color = AppColors.primary}) {
    return AppCard(
      color: AppColors.panel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MetricGlyph(glyph, color: color, box: 34),
        const SizedBox(height: 16),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        if (unit.isNotEmpty)
          Text(unit, style: const TextStyle(color: AppColors.muted)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device =
        Map<String, dynamic>.from((data?['device'] as Map?) ?? widget.device);
    final stats = Map<String, dynamic>.from((data?['stats'] as Map?) ?? {});
    final deviceClients = ((data?['deviceClients'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final lastError = asText(device['lastError'] ?? data?['message'], '');
    final model = asText(stats['model'], '');
    final firmware = asText(stats['firmware'], '');
    final essid = asText(stats['essid'], '');
    return Scaffold(
      appBar: AppBar(title: Text(asText(device['name']))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          AppCard(
            color: AppColors.cardSoft,
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asText(device['name']),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(asText(device['ip']),
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      if (model.isNotEmpty || firmware.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (model.isNotEmpty) model,
                            if (firmware.isNotEmpty) firmware,
                          ].join(' - '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (essid.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          essid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text('${asText(stats['uptime'], '--')} Uptime',
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              RadioDeviceBadge(model: model, size: 98),
            ]),
          ),
          if (lastError.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              color: AppColors.red.withOpacity(.08),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MiniIcon(Icons.error_outline_rounded,
                      color: AppColors.red, box: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lastError,
                      style: const TextStyle(
                          color: AppColors.red, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .72,
            children: [
              metric('clients', 'Clients', asText(stats['clients'], '0'), ''),
              metric('rx', 'RX', asText(stats['rxMbps'], '0'), 'Mbps'),
              metric('tx', 'TX', asText(stats['txMbps'], '0'), 'Mbps',
                  color: AppColors.warning),
              metric('noise', 'Noise', asText(stats['noise'], '--'), 'dBm',
                  color: AppColors.red),
              metric(
                  'distance', 'Distance', asText(stats['distance'], '--'), 'm',
                  color: AppColors.green),
              metric(
                  'freq', 'Frequency', asText(stats['frequency'], '--'), 'MHz',
                  color: AppColors.green),
              metric('ccq', 'CCQ', asText(stats['ccq'], '--'), '%'),
              metric('cpu', 'CPU', asText(stats['cpu'], '--'), '%'),
              metric('memory', 'Memory', asText(stats['memory'], '--'), '%'),
              metric(
                  'latency', 'Latency', asText(stats['txLatency'], '--'), 'ms',
                  color: AppColors.warning),
              metric(
                  'power', 'TX Power', asText(stats['txPower'], '--'), 'dBm'),
              metric('lan', 'LAN', asText(stats['lanSpeed'], '--'), ''),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => openClientsPage(device, deviceClients),
            borderRadius: BorderRadius.circular(18),
            child: AppCard(
              child: Row(
                children: [
                  const MiniIcon(Icons.groups_rounded, box: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clients',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deviceClients.isEmpty
                              ? 'لا توجد أجهزة مرتبطة حاليًا'
                              : '${deviceClients.length} جهاز مرتبط بالسكتور',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkDeviceClientsPage extends StatelessWidget {
  final Map<String, dynamic> device;
  final List<Map<String, dynamic>> clients;
  final Future<void> Function(String ip) onOpenIp;

  const NetworkDeviceClientsPage({
    super.key,
    required this.device,
    required this.clients,
    required this.onOpenIp,
  });

  Widget valueChip(
    IconData icon,
    String label,
    String value, {
    Color color = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withOpacity(.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget clientCard(Map<String, dynamic> client) {
    final ip = asText(client['ip'], '');
    final name = asText(client['name'], 'Client');
    final model = asText(client['model'], '');
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: NanoDeviceBadge(model: model, size: 76)),
          const SizedBox(height: 9),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (model.isNotEmpty && model != name) ...[
            const SizedBox(height: 4),
            Text(
              model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            ip.isEmpty ? 'IP غير متوفر' : ip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          valueChip(
            Icons.signal_cellular_alt_rounded,
            'Signal',
            asText(client['signal'], '-- dBm'),
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          valueChip(
            Icons.speed_rounded,
            'CCQ',
            asText(client['ccq'], '--'),
            color: AppColors.purple,
          ),
          const SizedBox(height: 6),
          valueChip(
            Icons.blur_on_rounded,
            'Noise Floor',
            asText(client['noise'], '-- dBm'),
            color: AppColors.red,
          ),
          const SizedBox(height: 6),
          valueChip(
            Icons.arrow_downward_rounded,
            'Rx Rate',
            asText(client['rxRate'], '-- Mbps'),
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          valueChip(
            Icons.arrow_upward_rounded,
            'Tx Rate',
            asText(client['txRate'], '-- Mbps'),
            color: AppColors.warning,
          ),
          const SizedBox(height: 6),
          valueChip(
            Icons.timer_rounded,
            'Uptime',
            asText(client['uptime'], '--'),
            color: AppColors.muted,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ip.isEmpty ? null : () => onOpenIp(ip),
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('فتح الجهاز'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('عملاء ${asText(device['name'])}')),
      body: clients.isEmpty
          ? const Center(
              child: Text(
                'لا توجد أجهزة مرتبطة حاليًا',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .30,
              ),
              itemCount: clients.length,
              itemBuilder: (_, index) => clientCard(clients[index]),
            ),
    );
  }
}

class MorePage extends StatelessWidget {
  final ApiService api;
  final VoidCallback onLogout;
  const MorePage({super.key, required this.api, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'المزيد',
      subtitle: 'إعدادات وأدوات النظام',
      children: [
        MoreSection(
          title: 'الحساب',
          children: [
            MoreTile(icon: Icons.person_rounded, label: 'حسابي', onTap: () {}),
            MoreTile(
              icon: Icons.history_rounded,
              label: 'سجل العمليات',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        MoreSection(
          title: 'النظام',
          children: [
            MoreTile(
              icon: Icons.notifications_rounded,
              label: 'التنبيهات',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RemindersPage(api: api)),
              ),
            ),
            MoreTile(
              icon: Icons.sync_rounded,
              label: 'مزامنة الساس',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SasSyncPage(api: api)),
              ),
            ),
            MoreTile(
              icon: Icons.system_update_rounded,
              label: 'التحديثات',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UpdatesPage(api: api)),
              ),
            ),
            MoreTile(
              icon: Icons.settings_rounded,
              label: 'الإعدادات',
              onTap: () {},
            ),
            MoreTile(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج من التطبيق',
              onTap: onLogout,
            ),
          ],
        ),
        const SizedBox(height: 12),
        MoreSection(
          title: 'الدعم لاحقًا',
          children: [
            MoreTile(
              icon: Icons.help_outline_rounded,
              label: 'مركز المساعدة',
              onTap: () {},
            ),
            MoreTile(
              icon: Icons.info_outline_rounded,
              label: 'عن Nodrix - $currentAppVersion',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const MoreSection({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}

class MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const MoreTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            MiniIcon(icon, box: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
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
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final result = await widget.api.syncSas();
      if (!mounted) return;
      if (result['ok'] == true) {
        setState(
          () => message =
              'تمت المزامنة بالخلفية: ${result['total'] ?? 0} مشترك، المتصلون: ${result['onlineTotal'] ?? 0}، الجلسات: ${result['sessionsTotal'] ?? 0}',
        );
        await loadStatus();
      } else {
        setState(
          () => message =
              '${asText(result['message'], 'فشلت المزامنة الخفية')}. استخدم دخول المتصفح فقط إذا احتاجت الجلسة إلى تسجيل دخول جديد.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message =
              'فشلت المزامنة الخفية: $e. استخدم دخول المتصفح فقط إذا احتاجت الجلسة إلى تسجيل دخول جديد.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clearMock() async {
    setState(() {
      clearing = true;
      message = '';
    });
    try {
      final result = await widget.api.clearMockData();
      if (!mounted) return;
      setState(
        () => message = result['ok'] == true
            ? 'تم تنظيف البيانات الوهمية: ${result['deleted'] ?? 0}'
            : asText(result['message'], 'فشل التنظيف'),
      );
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
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SasWebLoginPage(api: widget.api, sasUrl: url),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      setState(() => message = 'تم حفظ الجلسة وجلب البيانات من داخل المتصفح.');
      await loadStatus();
    }
  }

  Future<void> logoutSas() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final result = await widget.api.logoutSasSession();
      if (!mounted) return;
      setState(
        () => message = result['ok'] == true
            ? 'تم تسجيل الخروج من جلسة SAS المحفوظة'
            : asText(result['message'], 'فشل تسجيل الخروج'),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('لوحات الساس')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لوحة SAS المرتبطة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  configured
                      ? 'تم حفظ لوحة SAS. يمكنك المزامنة الآن لجلب كل المشتركين من اللوحة.'
                      : 'لم تحفظ لوحة SAS بعد. ارجع إلى شاشة الربط واحفظ الرابط واليوزر والباسورد أولًا.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                MetricLine(
                  'قاعدة البيانات',
                  asText(s['database'], 'postgresql'),
                ),
                MetricLine('نوع اللوحة', asText(s['source'], 'none')),
                MetricLine('الرابط', asText(s['panelUrl'], 'غير محفوظ')),
                MetricLine('اليوزر', asText(s['panelUsername'], 'غير محفوظ')),
                MetricLine('عدد مشتركين SAS', asText(s['count'], '0')),
                MetricLine(
                  'جلسة المتصفح',
                  s['hasToken'] == true ? 'محفوظة' : 'غير محفوظة',
                ),
                MetricLine(
                  'آخر مزامنة',
                  dateLabel(s['lastSyncedAt']),
                  last: true,
                ),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      message,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading ? null : sync,
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: Text(
                          loading ? 'جاري المزامنة...' : 'مزامنة خفية',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: clearing ? null : clearMock,
                        icon: const Icon(
                          Icons.cleaning_services_rounded,
                          size: 18,
                        ),
                        label: Text(clearing ? 'تنظيف...' : 'حذف الوهمي'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: openBrowserLogin,
                        icon: const Icon(Icons.public_rounded, size: 18),
                        label: const Text('دخول عبر المتصفح'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : logoutSas,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('خروج SAS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طريقة العمل',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 10),
                Text(
                  'بسبب Cloudflare تتم المزامنة من داخل المتصفح المدمج نفسه ثم تُرسل النتائج إلى Nodrix. زر مزامنة عبر المتصفح يفتح اللوحة، وإذا كانت الجلسة محفوظة يجلب المشتركين مباشرة.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RemindersPage extends StatelessWidget {
  final ApiService api;
  const RemindersPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التنبيهات')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: api.getReminderPreview(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معاينة التنبيهات',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'عدد الرسائل المقترحة: ${data['count'] ?? 0}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final result = await api.sendDemoReminders();
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت المحاكاة: ${result['sentCount'] ?? 0}',
                              ),
                            ),
                          );
                      },
                      child: const Text('إرسال تجريبي'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final result = await widget.api.getAppVersion();
      setState(() {
        data = result;
        message = result['ok'] == true
            ? 'تم فحص التحديثات'
            : asText(result['message'], 'تعذر الفحص');
      });
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط، تم نسخه للحافظة')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = asText(data?['latestVersion'], currentAppVersion);
    final hasUpdate = compareVersions(latest, currentAppVersion) > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('التحديثات')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة التطبيق',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                MetricLine('النسخة الحالية', currentAppVersion),
                MetricLine('آخر نسخة', latest),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading ? null : check,
                        child: Text(
                          loading ? 'جاري الفحص...' : 'فحص التحديثات',
                        ),
                      ),
                    ),
                    if (data != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: hasUpdate ? download : null,
                          child: const Text('تحميل'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
