import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

const String currentAppVersion = '1.0.4';
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
  static const bg = Color(0xFF0B0F14);
  static const bg2 = Color(0xFF101720);
  static const card = Color(0xFF141B24);
  static const card2 = Color(0xFF182231);
  static const border = Color(0xFF263241);
  static const text = Color(0xFFE7EDF5);
  static const muted = Color(0xFF8B98A8);
  static const accent = Color(0xFF0EA5E9);
  static const accent2 = Color(0xFF38BDF8);
  static const gold = Color(0xFFFACC15);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark).copyWith(
          primary: AppColors.accent,
          secondary: AppColors.gold,
          surface: AppColors.card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900),
          iconTheme: IconThemeData(color: AppColors.text),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.card,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: AppColors.border)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F141B),
          labelStyle: const TextStyle(color: AppColors.muted),
          hintStyle: const TextStyle(color: AppColors.muted),
          prefixIconColor: AppColors.muted,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.accent2, width: 1.4)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.red)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

String money(dynamic value) {
  final raw = value?.toString().replaceAll(',', '') ?? '0';
  final n = int.tryParse(raw) ?? 0;
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    b.write(s[i]);
    if (left > 1 && left % 3 == 1) b.write(',');
  }
  return '${b.toString()} د.ع';
}

Color statusColor(String status) {
  switch (status) {
    case 'active':
    case 'online':
      return AppColors.green;
    case 'expires_soon':
      return AppColors.orange;
    case 'expired':
    case 'offline':
      return AppColors.red;
    case 'paused':
      return AppColors.muted;
    default:
      return AppColors.muted;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'متصل';
    case 'expires_soon':
      return 'قريب من الانتهاء';
    case 'expired':
      return 'منتهي';
    case 'paused':
      return 'موقوف';
    case 'online':
      return 'Online';
    case 'offline':
      return 'Offline';
    default:
      return status;
  }
}

int compareVersions(String a, String b) {
  List<int> parse(String v) => v.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final pa = parse(a);
  final pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

extension IsoDate on DateTime {
  String shortDate() => toIso8601String().substring(0, 10);
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}

class RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const RoundIcon(this.icon, {super.key, this.color = AppColors.accent, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class StatusDot extends StatelessWidget {
  final String status;
  const StatusDot(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(statusLabel(status), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
    ]);
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final serverController = TextEditingController(text: defaultBackendUrl);
  final typeController = TextEditingController(text: 'mock');
  final sasUrlController = TextEditingController(text: 'https://demo.local');
  final usernameController = TextEditingController(text: 'admin');
  final passwordController = TextEditingController(text: 'admin123');
  String message = '';
  bool loading = false;
  ApiService get api => ApiService(baseUrl: serverController.text.trim());

  Future<void> testConnection() async {
    setState(() { loading = true; message = 'جاري اختبار الاتصال...'; });
    try {
      final result = await api.testConnection(type: typeController.text.trim(), sasUrl: sasUrlController.text.trim(), username: usernameController.text.trim(), password: passwordController.text.trim());
      setState(() => message = result['ok'] == true ? 'تم الاتصال بنجاح' : asText(result['message'], 'فشل الاتصال'));
    } catch (e) {
      setState(() => message = 'خطأ اتصال: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveAndContinue() async {
    setState(() { loading = true; message = 'جاري الحفظ...'; });
    try {
      await api.saveConfig(type: typeController.text.trim(), sasUrl: sasUrlController.text.trim(), username: usernameController.text.trim(), password: passwordController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(api: api)));
    } catch (e) {
      setState(() => message = 'فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget field(String label, TextEditingController c, IconData icon, {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, obscureText: secret, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 22),
            Center(
              child: Column(children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF1E293B)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.router_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 14),
                const Text('Nodrix', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.text)),
                const Text('إدارة الشبكة والمشتركين', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 28),
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('إعداد الاتصال', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('ضع رابط السيرفر ومعلومات الساس التجريبية.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              field('Backend URL', serverController, Icons.dns_rounded),
              field('SAS Type', typeController, Icons.tune_rounded),
              field('SAS URL', sasUrlController, Icons.link_rounded),
              field('Username', usernameController, Icons.person_rounded),
              field('Password', passwordController, Icons.lock_rounded, secret: true),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: loading ? null : testConnection, icon: const Icon(Icons.wifi_tethering_rounded), label: const Text('اختبار الاتصال')),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: loading ? null : saveAndContinue, icon: const Icon(Icons.login_rounded), label: const Text('حفظ ومتابعة')),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Text(message)),
              ],
            ])),
          ],
        ),
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

class _HomePageState extends State<HomePage> {
  int index = 0;
  int refreshToken = 0;
  void refresh() => setState(() => refreshToken++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomersPage(key: ValueKey('customers-$refreshToken'), api: widget.api),
      DevicesHubPage(key: ValueKey('devices-$refreshToken'), api: widget.api),
      DashboardPage(key: ValueKey('dash-$refreshToken'), api: widget.api),
      MorePage(key: ValueKey('more-$refreshToken'), api: widget.api),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(icon: Icons.people_alt_rounded, label: 'المشتركين', selected: index == 0, onTap: () => setState(() => index = 0)),
              NavItem(icon: Icons.sensors_rounded, label: 'الأجهزة', selected: index == 1, onTap: () => setState(() => index = 1)),
              NavItem(icon: Icons.bar_chart_rounded, label: 'الإحصائيات', selected: index == 2, onTap: () => setState(() => index = 2)),
              NavItem(icon: Icons.more_horiz_rounded, label: 'المزيد', selected: index == 3, onTap: () => setState(() => index = 3)),
            ],
          ),
        ),
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.bg2,
              foregroundColor: AppColors.text,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: const BorderSide(color: AppColors.border)),
              icon: const Icon(Icons.search_rounded),
              label: const Text('بحث'),
              onPressed: () {},
            )
          : null,
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? AppColors.text : AppColors.muted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: selected ? AppColors.text : AppColors.muted, fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
        ]),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const PageShell({super.key, required this.title, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 18),
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
  bool sortDebt = false;

  @override
  void initState() {
    super.initState();
    future = widget.api.getCustomers();
  }

  void reload() => setState(() => future = widget.api.getCustomers());

  Future<void> addCustomer() async {
    final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormPage(api: widget.api)));
    if (ok == true) reload();
  }

  void openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 72, height: 6, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 22),
            const Text('الترتيب حسب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              filterChip('all', 'الكل'),
              filterChip('active', 'متصل'),
              filterChip('expires_soon', 'قريب الانتهاء'),
              filterChip('expired', 'منتهي'),
              ChoiceChip(label: const Text('دين المشترك'), selected: sortDebt, onSelected: (v) => setState(() { sortDebt = v; Navigator.pop(context); })),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget filterChip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => setState(() { filter = value; Navigator.pop(context); }),
      );

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> all) {
    var list = all.where((c) {
      final q = query.trim().toLowerCase();
      final matchesQuery = q.isEmpty || ['name', 'username', 'phone', 'tower', 'sector'].any((k) => asText(c[k], '').toLowerCase().contains(q));
      final matchesFilter = filter == 'all' || asText(c['status']) == filter;
      return matchesQuery && matchesFilter;
    }).toList();
    if (sortDebt) {
      list.sort((a, b) => (int.tryParse(asText(b['debt'], '0')) ?? 0).compareTo(int.tryParse(asText(a['debt'], '0')) ?? 0));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final customers = snapshot.hasData ? applyFilters(snapshot.data!) : <Map<String, dynamic>>[];
        return PageShell(
          title: 'المشتركين',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton.filledTonal(onPressed: addCustomer, icon: const Icon(Icons.add_rounded)),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: openFilters, icon: const Icon(Icons.tune_rounded)),
          ]),
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(hintText: 'بحث عن مشترك', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            if (snapshot.hasError) GlassCard(child: Text('تعذر جلب المشتركين: ${snapshot.error}', style: const TextStyle(color: AppColors.red)))
            else if (!snapshot.hasData) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (customers.isEmpty) const GlassCard(child: Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.muted))))
            else ...customers.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CustomerTile(customer: c, onTap: () async {
                    final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailsPage(api: widget.api, customer: c)));
                    if (ok == true) reload();
                  }),
                )),
          ],
        );
      },
    );
  }
}

class CustomerTile extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;
  const CustomerTile({super.key, required this.customer, required this.onTap});

  int get remainingDays {
    final date = DateTime.tryParse(asText(customer['expiresAt'], ''));
    if (date == null) return 0;
    return date.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final status = asText(customer['status'], 'active');
    final days = remainingDays;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            width: 86,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: status == 'expired' ? [const Color(0xFF475569), const Color(0xFF1F2937)] : [AppColors.accent, const Color(0xFF075985)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(days <= 0 ? '—' : '$days', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w900)),
              Text(days <= 0 ? 'محجوب' : 'يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(days <= 0 ? '' : '14 ساعة', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(customer['name']), style: const TextStyle(fontSize: 18, color: AppColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              StatusDot(status),
              const SizedBox(height: 8),
              Text(money(customer['price']), style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900), textDirection: TextDirection.rtl),
              const SizedBox(height: 4),
              Text(asText(customer['username']), style: const TextStyle(color: AppColors.muted), textDirection: TextDirection.ltr),
            ]),
          ),
          Column(children: [
            const RoundIcon(Icons.check_rounded, color: Color(0xFF334155), size: 28),
            const SizedBox(height: 10),
            Text(asText(customer['tower'], 'LAN --'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class CustomerDetailsPage extends StatelessWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  const CustomerDetailsPage({super.key, required this.api, required this.customer});

  Future<bool?> edit(BuildContext context) => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerFormPage(api: api, customer: customer)));
  Future<bool?> payment(BuildContext context) => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentPage(api: api, customer: customer)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشترك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const RoundIcon(Icons.person_rounded, color: AppColors.accent, size: 58),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(customer['name']), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              StatusDot(asText(customer['status'], 'active')),
              Text(asText(customer['username']), style: const TextStyle(color: AppColors.muted), textDirection: TextDirection.ltr),
            ])),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoBox('الهاتف', customer['phone'], Icons.phone_rounded),
            InfoBox('الباقة', customer['package'], Icons.speed_rounded),
            InfoBox('السعر', money(customer['price']), Icons.payments_rounded),
            InfoBox('البرج', customer['tower'], Icons.cell_tower_rounded),
            InfoBox('السكتر', customer['sector'], Icons.router_rounded),
            InfoBox('الانتهاء', customer['expiresAt'], Icons.event_busy_rounded),
          ]),
          const SizedBox(height: 18),
          Text('ملاحظات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(asText(customer['notes'], 'لا توجد ملاحظات'), style: const TextStyle(color: AppColors.muted)),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () async { final ok = await edit(context); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit_rounded), label: const Text('تعديل'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await payment(context); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.payments_rounded), label: const Text('دفعة'))),
        ]),
      ]),
    );
  }
}

class InfoBox extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;
  const InfoBox(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.muted, size: 18),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        Text(asText(value), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
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
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name, phone, username, packageName, price, tower, sector, address, startedAt, expiresAt, notes;
  String status = 'active';
  bool saving = false;
  bool get editing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer ?? {};
    name = TextEditingController(text: asText(c['name'], ''));
    phone = TextEditingController(text: asText(c['phone'], ''));
    username = TextEditingController(text: asText(c['username'], ''));
    packageName = TextEditingController(text: asText(c['package'], 'ECO++'));
    price = TextEditingController(text: asText(c['price'], '25000'));
    tower = TextEditingController(text: asText(c['tower'], 'admin@samer'));
    sector = TextEditingController(text: asText(c['sector'], 'SR1'));
    address = TextEditingController(text: asText(c['address'], ''));
    startedAt = TextEditingController(text: asText(c['startedAt'], DateTime.now().shortDate()));
    expiresAt = TextEditingController(text: asText(c['expiresAt'], DateTime.now().add(const Duration(days: 30)).shortDate()));
    notes = TextEditingController(text: asText(c['notes'], ''));
    status = asText(c['status'], 'active');
  }

  Map<String, dynamic> payload() => {
    'name': name.text.trim(),
    'phone': phone.text.trim(),
    'username': username.text.trim(),
    'package': packageName.text.trim(),
    'price': int.tryParse(price.text.trim()) ?? 0,
    'tower': tower.text.trim(),
    'sector': sector.text.trim(),
    'address': address.text.trim(),
    'startedAt': startedAt.text.trim(),
    'expiresAt': expiresAt.text.trim(),
    'notes': notes.text.trim(),
    'status': status,
  };

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final result = editing ? await widget.api.updateCustomer(widget.customer!['id'], payload()) : await widget.api.addCustomer(payload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'تم الحفظ'))));
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(String label, TextEditingController c, IconData icon, {bool required = false, TextInputType? type, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        textDirection: type == TextInputType.phone || type == TextInputType.number ? TextDirection.ltr : TextDirection.rtl,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل مشترك' : 'إضافة مشترك')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: FilledButton(onPressed: saving ? null : save, child: Text(editing ? 'حفظ التعديل' : 'إضافة')),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
          GlassCard(child: Column(children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'الوقت'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('فعال')),
                  DropdownMenuItem(value: 'expires_soon', child: Text('قريب من الانتهاء')),
                  DropdownMenuItem(value: 'expired', child: Text('منتهي')),
                  DropdownMenuItem(value: 'paused', child: Text('موقوف')),
                ],
                onChanged: (v) => setState(() => status = v ?? 'active'),
              )),
              const SizedBox(width: 12),
              Expanded(child: input('اليوزر', username, Icons.person_pin_rounded)),
            ]),
            input('الاسم', name, Icons.person_rounded, required: true),
            input('النوع', packageName, Icons.check_circle_rounded, required: true),
            input('كلمة المرور', notes, Icons.password_rounded),
            input('رقم الهاتف الأول (هاتف + واتساب)', phone, Icons.phone_rounded, required: true, type: TextInputType.phone),
            input('رقم الهاتف الثاني (هاتف فقط)', TextEditingController(), Icons.phone_in_talk_rounded, type: TextInputType.phone),
            input('ديون سابقة', price, Icons.payments_rounded, type: TextInputType.number),
            input('IP النانو', address, Icons.hub_rounded),
            Row(children: [
              Expanded(child: input('البرج', tower, Icons.cell_tower_rounded)),
              const SizedBox(width: 12),
              Expanded(child: input('باسورد', sector, Icons.router_rounded)),
            ]),
            Row(children: [
              Expanded(child: input('بداية الاشتراك', startedAt, Icons.event_available_rounded)),
              const SizedBox(width: 12),
              Expanded(child: input('نهاية الاشتراك', expiresAt, Icons.event_busy_rounded)),
            ]),
          ])),
        ]),
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
  late final TextEditingController amount, date, expiresAt;
  final note = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: asText(widget.customer['price'], ''));
    date = TextEditingController(text: DateTime.now().shortDate());
    expiresAt = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).shortDate());
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final result = await widget.api.addPayment(widget.customer['id'], {'amount': int.tryParse(amount.text.trim()) ?? 0, 'date': date.text.trim(), 'expiresAt': expiresAt.text.trim(), 'note': note.text.trim()});
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
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: c, keyboardType: type, textDirection: type == TextInputType.number ? TextDirection.ltr : TextDirection.rtl, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('تسجيل دفعة')), body: ListView(padding: const EdgeInsets.all(20), children: [
      GlassCard(child: Column(children: [
        input('المبلغ', amount, Icons.payments_rounded, type: TextInputType.number),
        input('تاريخ الدفع', date, Icons.calendar_today_rounded),
        input('تاريخ الانتهاء الجديد', expiresAt, Icons.event_busy_rounded),
        input('ملاحظة', note, Icons.notes_rounded),
        FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ الدفعة')),
      ])),
    ]));
  }
}

class DevicesHubPage extends StatefulWidget {
  final ApiService api;
  const DevicesHubPage({super.key, required this.api});
  @override
  State<DevicesHubPage> createState() => _DevicesHubPageState();
}

class _DevicesHubPageState extends State<DevicesHubPage> with SingleTickerProviderStateMixin {
  late final TabController tab = TabController(length: 4, vsync: this);
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(children: [
          Expanded(child: Container(height: 54, decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Center(child: Text('الكل', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w900))))),
          const SizedBox(width: 14),
          IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
        ]),
      ),
      TabBar(controller: tab, labelColor: AppColors.accent2, unselectedLabelColor: AppColors.muted, indicatorColor: AppColors.accent2, tabs: const [Tab(text: 'Sector'), Tab(text: 'Link'), Tab(text: 'Switch'), Tab(text: 'Ping')]),
      Expanded(child: TabBarView(controller: tab, children: [
        DeviceList(title: 'السكاترات', loader: widget.api.getSectors, sectorStyle: true),
        DeviceList(title: 'اللنكات', loader: widget.api.getLinks),
        const ComingSoon(label: 'السويتجات'),
        const ComingSoon(label: 'Ping Tools'),
      ])),
    ]));
  }
}

class DeviceList extends StatelessWidget {
  final String title;
  final Future<List<dynamic>> Function() loader;
  final bool sectorStyle;
  const DeviceList({super.key, required this.title, required this.loader, this.sectorStyle = false});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: DeviceCard(item: Map<String, dynamic>.from(items[i] as Map), sectorStyle: sectorStyle)),
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool sectorStyle;
  const DeviceCard({super.key, required this.item, required this.sectorStyle});
  @override
  Widget build(BuildContext context) {
    final online = asText(item['status'], 'online') == 'online';
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: online ? [const Color(0xFF0F4C75), const Color(0xFF075985)] : [const Color(0xFF334155), const Color(0xFF111827)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(item['name'], 'SR'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.language_rounded, size: 18, color: Colors.white70), const SizedBox(width: 6), Text(asText(item['ip'], '10.43.226.200'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))]),
            ])),
            Container(width: 82, height: 118, decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(18)), child: Icon(sectorStyle ? Icons.router_rounded : Icons.hub_rounded, color: Colors.blueGrey, size: 46)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            DeviceMetric('8', 'Clients', Icons.people_rounded),
            DeviceMetric(asText(item['rx'], '1.60 Mbps'), 'Rx', Icons.south_rounded),
            DeviceMetric(asText(item['tx'], '0.88 Mbps'), 'Tx', Icons.north_rounded),
            DeviceMetric(asText(item['ethernet'], '100 Mbps'), 'Ethernet', Icons.settings_ethernet_rounded),
            DeviceMetric(asText(item['noise'], '-88 dBm'), 'Noise', Icons.grain_rounded),
            DeviceMetric(asText(item['uptime'], '2d 5h 17m'), 'Uptime', Icons.timer_rounded),
          ]),
        ),
      ]),
    );
  }
}

class DeviceMetric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const DeviceMetric(this.value, this.label, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(width: 100, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.muted, size: 17),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ]));
  }
}

class ComingSoon extends StatelessWidget {
  final String label;
  const ComingSoon({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Center(child: GlassCard(child: Text('$label - قريبًا', style: const TextStyle(fontWeight: FontWeight.w900))));
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
        return PageShell(title: 'الإحصائيات', children: [
          if (!snapshot.hasData && !snapshot.hasError) const Center(child: CircularProgressIndicator()),
          if (snapshot.hasError) GlassCard(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.red))),
          if (snapshot.hasData) ...[
            GlassCard(color: AppColors.card2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.gold),
              const SizedBox(height: 8),
              BigStat('عدد المشتركين', asText(data['totalCustomers'], '0')),
              BigStat('الدين الكلي', money(data['totalDebt'] ?? 3410000)),
              BigStat('الإيداع الكلي', money(data['incomeToday'] ?? 0)),
            ])),
            const SizedBox(height: 16),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2, children: [
              StatCard('فعال', asText(data['activeCustomers'], '0'), Icons.check_circle_rounded, AppColors.green),
              StatCard('قريب الانتهاء', asText(data['expiresSoon'], '0'), Icons.warning_rounded, AppColors.orange),
              StatCard('منتهي', asText(data['expiredCustomers'], '0'), Icons.cancel_rounded, AppColors.red),
              StatCard('دخل الشهر', money(data['incomeMonth'] ?? 0), Icons.payments_rounded, AppColors.accent),
            ]),
          ],
        ]);
      },
    );
  }
}

class BigStat extends StatelessWidget {
  final String label, value;
  const BigStat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]));
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const StatCard(this.title, this.value, this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [RoundIcon(icon, color: color), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))]));
}

class MorePage extends StatelessWidget {
  final ApiService api;
  const MorePage({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    return PageShell(title: 'المزيد', children: [
      GlassCard(child: Column(children: [
        MoreTile(icon: Icons.person_rounded, label: 'حسابي', color: Colors.blue, onTap: () {}),
        MoreTile(icon: Icons.dashboard_rounded, label: 'اللوحات', color: Colors.deepPurple, onTap: () {}),
        MoreTile(icon: Icons.history_rounded, label: 'سجل العمليات', color: Colors.indigo, onTap: () {}),
        MoreTile(icon: Icons.picture_as_pdf_rounded, label: 'تصدير ملف PDF', color: Colors.red, onTap: () {}),
      ])),
      const SizedBox(height: 14),
      GlassCard(child: Column(children: [
        MoreTile(icon: Icons.notifications_rounded, label: 'إرسال إشعار', color: Colors.amber, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemindersPage(api: api)))),
        MoreTile(icon: Icons.sync_rounded, label: 'التنبيهات التلقائية', color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemindersPage(api: api)))),
        MoreTile(icon: Icons.system_update_rounded, label: 'التحديثات', color: Colors.cyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesPage(api: api)))),
        MoreTile(icon: Icons.settings_rounded, label: 'الإعدادات', color: Colors.blueGrey, onTap: () {}),
      ])),
      const SizedBox(height: 14),
      GlassCard(child: MoreTile(icon: Icons.telegram_rounded, label: 'أكثر عن التطبيق\n$currentAppVersion', color: Colors.lightBlue, onTap: () {})),
    ]);
  }
}

class MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const MoreTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: RoundIcon(icon, color: color),
      title: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
    );
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
        return ListView(padding: const EdgeInsets.all(20), children: [
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('معاينة التنبيهات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('المستحقون للتنبيه: ${asText(data['count'], '0')}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () async { final r = await api.sendDemoReminders(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(r['message'], 'تم الإرسال التجريبي')))); }, icon: const Icon(Icons.send_rounded), label: const Text('إرسال تجريبي')),
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
  Map<String, dynamic>? data;
  bool loading = false;
  String message = '';

  Future<void> check() async {
    setState(() { loading = true; message = ''; });
    try {
      final r = await widget.api.getAppVersion();
      setState(() => data = r);
    } catch (e) {
      setState(() => message = 'تعذر جلب التحديث: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openDownload() async {
    final url = asText(data?['apkUrl'], '');
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط، تم نسخه للحافظة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = asText(data?['latestVersion'], currentAppVersion);
    final hasUpdate = data != null && compareVersions(latest, currentAppVersion) > 0;
    return Scaffold(appBar: AppBar(title: const Text('التحديثات')), body: ListView(padding: const EdgeInsets.all(20), children: [
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RoundIcon(Icons.system_update_rounded, color: AppColors.accent, size: 58),
        const SizedBox(height: 18),
        Text('النسخة الحالية: $currentAppVersion', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        Text(data == null ? 'اضغط فحص التحديثات لمعرفة آخر نسخة.' : 'آخر نسخة: $latest', style: const TextStyle(color: AppColors.muted)),
        if (asText(data?['notes'], '').isNotEmpty) ...[const SizedBox(height: 8), Text(asText(data?['notes']), style: const TextStyle(color: AppColors.muted))],
        if (message.isNotEmpty) ...[const SizedBox(height: 12), Text(message, style: const TextStyle(color: AppColors.red))],
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: loading ? null : check, icon: const Icon(Icons.refresh_rounded), label: Text(loading ? 'جاري الفحص...' : 'فحص التحديثات')),
        const SizedBox(height: 10),
        if (hasUpdate) FilledButton.icon(onPressed: openDownload, icon: const Icon(Icons.download_rounded), label: const Text('تحميل التحديث'))
        else if (data != null) const Text('أنت على آخر نسخة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w900)),
      ])),
    ]));
  }
}
