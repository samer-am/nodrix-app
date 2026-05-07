import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

const String currentAppVersion = '1.0.3';
const String defaultBackendUrl = 'https://nodrix-app-production.up.railway.app';

void main() => runApp(const NodrixApp());

class NodrixApp extends StatelessWidget {
  const NodrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nodrix',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: seed, width: 1.5)),
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
  final n = int.tryParse(value.toString()) ?? 0;
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final left = s.length - i;
    buffer.write(s[i]);
    if (left > 1 && left % 3 == 1) buffer.write(',');
  }
  return '${buffer.toString()} د.ع';
}

Color statusColor(String status) {
  switch (status) {
    case 'online':
    case 'active':
      return const Color(0xFF16A34A);
    case 'expires_soon':
      return const Color(0xFFF59E0B);
    case 'offline':
    case 'expired':
      return const Color(0xFFDC2626);
    case 'paused':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF64748B);
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'فعّال';
    case 'expires_soon':
      return 'قريب الانتهاء';
    case 'expired':
      return 'منتهي';
    case 'paused':
      return 'موقوف';
    case 'online':
      return 'متصل';
    case 'offline':
      return 'غير متصل';
    default:
      return status;
  }
}

int compareVersions(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final maxLen = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < maxLen; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(999)),
      child: Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  const SectionTitle({super.key, required this.title, this.subtitle, required this.icon, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  const InfoChip(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        Text(asText(value), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ]),
    );
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
      final result = await api.testConnection(
        type: typeController.text.trim(),
        sasUrl: sasUrlController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
      setState(() => message = result['ok'] == true ? 'تم الاتصال بنجاح' : asText(result['message'], 'فشل الاتصال'));
    } catch (e) {
      setState(() => message = 'خطأ اتصال: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> saveAndContinue() async {
    setState(() { loading = true; message = 'جاري الحفظ...'; });
    try {
      await api.saveConfig(
        type: typeController.text.trim(),
        sasUrl: sasUrlController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(api: api)));
    } catch (e) {
      setState(() => message = 'فشل حفظ الإعدادات: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Widget field(String label, TextEditingController controller, {bool secret = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 18),
              Row(children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.network_check, color: Colors.white, size: 30)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nodrix', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text('إدارة المشتركين والسكاترات والتحديثات', style: TextStyle(color: Colors.grey.shade700)),
                ]),
              ]),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle(title: 'إعداد الاتصال', subtitle: 'النسخة الحالية تعمل على محول mock للتجربة', icon: Icons.settings_ethernet),
                    const SizedBox(height: 20),
                    field('رابط السيرفر', serverController, icon: Icons.dns),
                    field('نوع الساس', typeController, icon: Icons.extension),
                    field('رابط الساس', sasUrlController, icon: Icons.link),
                    field('اسم المستخدم', usernameController, icon: Icons.person),
                    field('كلمة المرور', passwordController, secret: true, icon: Icons.lock),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: loading ? null : testConnection, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering), label: const Text('اختبار الاتصال'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(onPressed: loading ? null : saveAndContinue, icon: const Icon(Icons.login), label: const Text('حفظ ومتابعة'))),
                    ]),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: Text(message)),
                    ],
                  ]),
                ),
              ),
            ],
          ),
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
      DashboardPage(key: ValueKey('dash-$refreshToken'), api: widget.api),
      CustomersPage(key: ValueKey('cust-$refreshToken'), api: widget.api),
      DevicesPage(key: ValueKey('sec-$refreshToken'), title: 'السكاترات', icon: Icons.cell_tower, loader: widget.api.getSectors),
      DevicesPage(key: ValueKey('link-$refreshToken'), title: 'اللنكات', icon: Icons.hub, loader: widget.api.getLinks),
      RemindersPage(key: ValueKey('rem-$refreshToken'), api: widget.api),
      UpdatesPage(key: ValueKey('upd-$refreshToken'), api: widget.api),
    ];
    final titles = ['الرئيسية', 'المشتركين', 'السكاترات', 'اللنكات', 'التنبيهات', 'التحديثات'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        actions: [Padding(padding: const EdgeInsets.only(left: 12), child: FilledButton.tonalIcon(onPressed: refresh, icon: const Icon(Icons.refresh), label: const Text('تحديث')))],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'المشتركين'),
          NavigationDestination(icon: Icon(Icons.cell_tower_outlined), selectedIcon: Icon(Icons.cell_tower), label: 'السكاترات'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'اللنكات'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'التنبيهات'),
          NavigationDestination(icon: Icon(Icons.system_update_alt), selectedIcon: Icon(Icons.system_update), label: 'التحديثات'),
        ],
      ),
    );
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
        if (snapshot.hasError) return Center(child: Text('خطأ في الرئيسية: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data['ok'] == false) return Center(child: Text(asText(data['message'], 'السيرفر رفض الطلب')));
        final cards = [
          _Metric('إجمالي المشتركين', data['totalCustomers'] ?? 0, Icons.groups, const Color(0xFF2563EB)),
          _Metric('مشترك فعّال', data['activeCustomers'] ?? 0, Icons.verified_user, const Color(0xFF16A34A)),
          _Metric('قريب الانتهاء', data['expiresSoon'] ?? 0, Icons.schedule, const Color(0xFFF59E0B)),
          _Metric('مشترك منتهي', data['expiredCustomers'] ?? 0, Icons.block, const Color(0xFFDC2626)),
          _Metric('دخل اليوم', money(data['incomeToday']), Icons.payments, const Color(0xFF0891B2)),
          _Metric('دخل الشهر', money(data['incomeMonth']), Icons.bar_chart, const Color(0xFF4F46E5)),
          _Metric('سكاترات متصلة', data['sectorsOnline'] ?? 0, Icons.router, const Color(0xFF0F766E)),
          _Metric('لنكات متصلة', data['linksOnline'] ?? 0, Icons.hub, const Color(0xFF7C3AED)),
        ];
        return ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle(title: 'لوحة التحكم', subtitle: 'ملخص سريع للتشغيل والمشتركين. البيانات محفوظة مؤقتًا على mock.', icon: Icons.insights),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 950 ? 4 : constraints.maxWidth > 620 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 1.48, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemBuilder: (_, i) => MetricCard(metric: cards[i]),
            );
          }),
        ]);
      },
    );
  }
}

class _Metric {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  _Metric(this.label, this.value, this.icon, this.color);
}

class MetricCard extends StatelessWidget {
  final _Metric metric;
  const MetricCard({super.key, required this.metric});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: metric.color.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Icon(metric.icon, color: metric.color)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${metric.value}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        Text(metric.label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
      ]),
    ])));
  }
}

class CustomersPage extends StatefulWidget {
  final ApiService api;
  const CustomersPage({super.key, required this.api});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String query = '';
  String filter = 'all';
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.getCustomers();
  }

  void refresh() => setState(() => future = widget.api.getCustomers());

  Future<void> openEditor([Map<String, dynamic>? customer]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CustomerFormPage(api: widget.api, customer: customer)));
    if (changed == true) refresh();
  }

  Future<void> openDetails(Map<String, dynamic> customer) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CustomerDetailsPage(api: widget.api, customer: customer)));
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في المشتركين: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final items = all.where((c) {
          final text = '${c['name']} ${c['phone']} ${c['tower']} ${c['sector']} ${c['username']}'.toLowerCase();
          return (query.isEmpty || text.contains(query.toLowerCase())) && (filter == 'all' || c['status'] == filter);
        }).toList();
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => openEditor(), icon: const Icon(Icons.person_add), label: const Text('إضافة مشترك')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SectionTitle(title: 'المشتركين', subtitle: '${items.length} نتيجة من ${all.length}', icon: Icons.people_alt, action: IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))),
            const SizedBox(height: 16),
            TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم، الهاتف، اليوزر، البرج أو السكتر')),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              FilterChip(label: const Text('الكل'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
              const SizedBox(width: 8),
              FilterChip(label: const Text('فعّال'), selected: filter == 'active', onSelected: (_) => setState(() => filter = 'active')),
              const SizedBox(width: 8),
              FilterChip(label: const Text('قريب الانتهاء'), selected: filter == 'expires_soon', onSelected: (_) => setState(() => filter = 'expires_soon')),
              const SizedBox(width: 8),
              FilterChip(label: const Text('منتهي'), selected: filter == 'expired', onSelected: (_) => setState(() => filter = 'expired')),
              const SizedBox(width: 8),
              FilterChip(label: const Text('موقوف'), selected: filter == 'paused', onSelected: (_) => setState(() => filter = 'paused')),
            ])),
            const SizedBox(height: 12),
            if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد نتائج مطابقة.'))),
            ...items.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: CustomerCard(customer: c, onTap: () => openDetails(c), onEdit: () => openEditor(c)))),
            const SizedBox(height: 86),
          ]),
        );
      },
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const CustomerCard({super.key, required this.customer, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12), child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asText(customer['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(asText(customer['phone']), textDirection: TextDirection.ltr, style: TextStyle(color: Colors.grey.shade700)),
              ])),
              StatusPill(asText(customer['status'], 'active')),
            ]),
            const SizedBox(height: 12),
            Wrap(children: [
              InfoChip(Icons.speed, 'الباقة', customer['package']),
              InfoChip(Icons.payments, 'السعر', money(customer['price'])),
              InfoChip(Icons.cell_tower, 'البرج', customer['tower']),
              InfoChip(Icons.router, 'السكتر', customer['sector']),
              InfoChip(Icons.event_busy, 'الانتهاء', customer['expiresAt']),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('تعديل'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.tonalIcon(onPressed: onTap, icon: const Icon(Icons.visibility), label: const Text('تفاصيل'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class CustomerDetailsPage extends StatelessWidget {
  final ApiService api;
  final Map<String, dynamic> customer;
  const CustomerDetailsPage({super.key, required this.api, required this.customer});

  Future<bool?> edit(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CustomerFormPage(api: api, customer: customer)));
  Future<bool?> payment(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PaymentPage(api: api, customer: customer)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشترك')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12), child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 30)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(customer['name']), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              Text(asText(customer['phone']), textDirection: TextDirection.ltr, style: TextStyle(color: Colors.grey.shade700)),
            ])),
            StatusPill(asText(customer['status'], 'active')),
          ]),
          const SizedBox(height: 18),
          Wrap(children: [
            InfoChip(Icons.account_circle, 'اليوزر', customer['username']),
            InfoChip(Icons.speed, 'الباقة', customer['package']),
            InfoChip(Icons.payments, 'السعر', money(customer['price'])),
            InfoChip(Icons.cell_tower, 'البرج', customer['tower']),
            InfoChip(Icons.router, 'السكتر', customer['sector']),
            InfoChip(Icons.event_available, 'البداية', customer['startedAt']),
            InfoChip(Icons.event_busy, 'الانتهاء', customer['expiresAt']),
            InfoChip(Icons.receipt_long, 'آخر دفعة', customer['lastPaymentAt']),
          ]),
          const SizedBox(height: 10),
          Text('العنوان', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(asText(customer['address']), style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Text('ملاحظات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(asText(customer['notes'], 'لا توجد ملاحظات'), style: TextStyle(color: Colors.grey.shade700)),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () async { final ok = await edit(context); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit), label: const Text('تعديل البيانات'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await payment(context); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.payments), label: const Text('تسجيل دفعة'))),
        ]),
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
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController username;
  late final TextEditingController package;
  late final TextEditingController price;
  late final TextEditingController tower;
  late final TextEditingController sector;
  late final TextEditingController address;
  late final TextEditingController startedAt;
  late final TextEditingController expiresAt;
  late final TextEditingController notes;
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
    package = TextEditingController(text: asText(c['package'], ''));
    price = TextEditingController(text: asText(c['price'], ''));
    tower = TextEditingController(text: asText(c['tower'], ''));
    sector = TextEditingController(text: asText(c['sector'], ''));
    address = TextEditingController(text: asText(c['address'], ''));
    startedAt = TextEditingController(text: asText(c['startedAt'], DateTime.now().toISOString().slice(0, 10)));
    expiresAt = TextEditingController(text: asText(c['expiresAt'], DateTime.now().add(const Duration(days: 30)).toISOString().slice(0, 10)));
    notes = TextEditingController(text: asText(c['notes'], ''));
    status = asText(c['status'], 'active');
  }

  Map<String, dynamic> payload() => {
    'name': name.text.trim(),
    'phone': phone.text.trim(),
    'username': username.text.trim(),
    'package': package.text.trim(),
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
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'تم الحفظ'))));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'فشل الحفظ'))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(String label, TextEditingController controller, {IconData? icon, bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: keyboardType == TextInputType.phone || keyboardType == TextInputType.number ? TextDirection.ltr : TextDirection.rtl,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل مشترك' : 'إضافة مشترك')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionTitle(title: editing ? 'تعديل بيانات المشترك' : 'مشترك جديد', subtitle: 'هذه البيانات محفوظة مؤقتًا على mock backend حاليًا', icon: editing ? Icons.edit : Icons.person_add),
          const SizedBox(height: 16),
          input('اسم المشترك', name, icon: Icons.person, required: true),
          input('رقم الهاتف', phone, icon: Icons.phone, required: true, keyboardType: TextInputType.phone),
          input('اسم المستخدم / PPPoE', username, icon: Icons.account_circle),
          input('الباقة', package, icon: Icons.speed, required: true),
          input('السعر', price, icon: Icons.payments, keyboardType: TextInputType.number),
          Row(children: [
            Expanded(child: input('البرج', tower, icon: Icons.cell_tower)),
            const SizedBox(width: 10),
            Expanded(child: input('السكتر', sector, icon: Icons.router)),
          ]),
          Row(children: [
            Expanded(child: input('تاريخ البداية', startedAt, icon: Icons.event_available)),
            const SizedBox(width: 10),
            Expanded(child: input('تاريخ الانتهاء', expiresAt, icon: Icons.event_busy)),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'حالة الاشتراك', prefixIcon: Icon(Icons.toggle_on)),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('فعّال')),
                DropdownMenuItem(value: 'expires_soon', child: Text('قريب الانتهاء')),
                DropdownMenuItem(value: 'expired', child: Text('منتهي')),
                DropdownMenuItem(value: 'paused', child: Text('موقوف')),
              ],
              onChanged: (v) => setState(() => status = v ?? 'active'),
            ),
          ),
          input('العنوان', address, icon: Icons.location_on, maxLines: 2),
          input('ملاحظات', notes, icon: Icons.notes, maxLines: 3),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(editing ? 'حفظ التعديل' : 'إضافة المشترك')),
        ]),
      ),
    );
  }
}

extension IsoDate on DateTime {
  String toISOString() => toIso8601String().slice(0, 10);
}

extension SliceString on String {
  String slice(int start, [int? end]) => substring(start, end);
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
  late final TextEditingController date;
  late final TextEditingController expiresAt;
  final note = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: asText(widget.customer['price'], ''));
    date = TextEditingController(text: DateTime.now().toISOString());
    expiresAt = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toISOString());
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final result = await widget.api.addPayment(widget.customer['id'], {
        'amount': int.tryParse(amount.text.trim()) ?? 0,
        'date': date.text.trim(),
        'expiresAt': expiresAt.text.trim(),
        'note': note.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(result['message'], 'تمت العملية'))));
      if (result['ok'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(String label, TextEditingController controller, {IconData? icon, TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: keyboardType, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('تسجيل دفعة')), body: ListView(padding: const EdgeInsets.all(16), children: [
      SectionTitle(title: 'دفعة جديدة', subtitle: 'المشترك: ${asText(widget.customer['name'])}', icon: Icons.payments),
      const SizedBox(height: 16),
      input('المبلغ', amount, icon: Icons.money, keyboardType: TextInputType.number),
      input('تاريخ الدفع', date, icon: Icons.event),
      input('تاريخ الانتهاء الجديد', expiresAt, icon: Icons.event_busy),
      TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظة', prefixIcon: Icon(Icons.notes))),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: const Text('حفظ الدفعة')),
    ]));
  }
}

class DevicesPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<List<dynamic>> Function() loader;
  const DevicesPage({super.key, required this.title, required this.icon, required this.loader});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!.cast<Map<String, dynamic>>();
        return ListView(padding: const EdgeInsets.all(16), children: [
          SectionTitle(title: title, subtitle: 'عرض حالة الأجهزة التجريبية', icon: icon),
          const SizedBox(height: 16),
          ...items.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DeviceCard(device: d))),
        ]);
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  const DeviceCard({super.key, required this.device});
  @override
  Widget build(BuildContext context) {
    final isLink = device['from'] != null;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(asText(device['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        StatusPill(asText(device['status'], 'offline')),
      ]),
      const SizedBox(height: 10),
      Wrap(children: [
        InfoChip(Icons.language, 'IP', device['ip']),
        InfoChip(Icons.memory, 'النوع', device['type']),
        if (device['tower'] != null) InfoChip(Icons.cell_tower, 'البرج', device['tower']),
        if (device['clients'] != null) InfoChip(Icons.people, 'العملاء', device['clients']),
        if (device['signal'] != null) InfoChip(Icons.network_check, 'الإشارة', device['signal']),
        if (device['capacity'] != null) InfoChip(Icons.speed, 'السعة', device['capacity']),
        if (device['traffic'] != null) InfoChip(Icons.query_stats, 'الترافيك', device['traffic']),
        InfoChip(Icons.timer, 'مدة التشغيل', device['uptime']),
      ]),
      if (isLink) ...[const SizedBox(height: 8), Text('${device['from']} ← ${device['to']}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700))],
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.open_in_browser), label: const Text('فتح')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.monitor_heart), label: const Text('فحص')),
      ]),
    ])));
  }
}

class RemindersPage extends StatefulWidget {
  final ApiService api;
  const RemindersPage({super.key, required this.api});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  late Future<Map<String, dynamic>> future;
  String sendResult = '';
  @override
  void initState() { super.initState(); future = widget.api.getReminderPreview(); }
  void refresh() => setState(() => future = widget.api.getReminderPreview());
  Future<void> sendDemo() async { final result = await widget.api.sendDemoReminders(); setState(() => sendResult = '${result['note'] ?? 'تمت المحاكاة'} العدد: ${result['sentCount'] ?? 0}'); refresh(); }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في التنبيهات: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data['ok'] == false) return Center(child: Text(asText(data['message'], 'السيرفر رفض الطلب')));
        final reminders = (data['reminders'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        return ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle(title: 'تنبيهات واتساب', subtitle: 'محاكاة فقط. لا يتم إرسال رسائل حقيقية الآن.', icon: Icons.mark_chat_unread),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تنبيهات جاهزة: ${data['count']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('يحسب السيرفر المشتركين المطلوب تنبيههم قبل 72/48/24 ساعة.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: sendDemo, icon: const Icon(Icons.send), label: const Text('إرسال تجريبي')),
            if (sendResult.isNotEmpty) ...[const SizedBox(height: 12), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Text(sendResult))],
          ]))),
          const SizedBox(height: 12),
          if (reminders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تنبيهات مستحقة الآن.'))),
          ...reminders.map((r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.message)), title: Text('${r['name']} - ${r['phone']}', style: const TextStyle(fontWeight: FontWeight.w800), textDirection: TextDirection.ltr), subtitle: Text('ينتهي: ${r['expiresAt']} • الساعات المتبقية: ${r['remainingHours']}\n${r['message']}'))))),
        ]);
      },
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
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); future = widget.api.getAppVersion(); }
  void refresh() => setState(() => future = widget.api.getAppVersion());

  Future<void> openDownload(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط التحديث غير صحيح. تم نسخه للحافظة.')));
      return;
    }
    for (final mode in [LaunchMode.externalApplication, LaunchMode.platformDefault]) {
      try {
        final opened = await launchUrl(uri, mode: mode);
        if (opened) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح التحميل مباشرة. تم نسخ الرابط للحافظة.')));
  }

  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في فحص التحديثات: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final latest = asText(data['latestVersion'], currentAppVersion);
        final apkUrl = asText(data['apkUrl'], '');
        final notes = asText(data['notes'], 'لا توجد ملاحظات.');
        final hasUpdate = compareVersions(latest, currentAppVersion) > 0;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle(title: 'تحديثات التطبيق', subtitle: 'رقم النسخة الحالي مضبوط داخل التطبيق الآن.', icon: Icons.system_update_alt),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(children: [
              InfoChip(Icons.phone_android, 'نسختك الحالية', currentAppVersion),
              InfoChip(Icons.cloud_download, 'آخر نسخة', latest),
            ]),
            const SizedBox(height: 14),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: hasUpdate ? Colors.orange.withOpacity(.12) : Colors.green.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Text(hasUpdate ? 'يوجد تحديث جديد متاح.' : 'أنت تستخدم آخر نسخة متاحة.', style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 14),
            Text('ملاحظات التحديث', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(notes),
            const SizedBox(height: 14),
            if (apkUrl.isNotEmpty) ...[
              SelectableText(apkUrl, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: hasUpdate ? () => openDownload(apkUrl) : null, icon: const Icon(Icons.download), label: const Text('تحميل التحديث'))),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => copyText(apkUrl), icon: const Icon(Icons.copy), label: const Text('نسخ')),
              ]),
            ] else const Text('لم يتم تحديد رابط APK بعد.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh), label: const Text('إعادة الفحص')),
          ]))),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('ملاحظة: أندرويد سيطلب موافقتك عند تثبيت APK.'))),
        ]);
      },
    );
  }
}
