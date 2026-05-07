import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

const String currentAppVersion = '0.2.0';
const String defaultBackendUrl = 'https://nodrix-app-production.up.railway.app';

void main() {
  runApp(const NodrixApp());
}

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
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: seed, width: 1.4)),
        ),
      ),
      home: const SetupPage(),
    );
  }
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
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999)),
      child: Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const AppSectionTitle({super.key, required this.title, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
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
    setState(() {
      loading = true;
      message = 'جاري اختبار الاتصال...';
    });
    try {
      final result = await api.testConnection(
        type: typeController.text.trim(),
        sasUrl: sasUrlController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
      setState(() => message = result['ok'] == true ? 'تم الاتصال بنجاح' : (result['message']?.toString() ?? 'فشل الاتصال'));
    } catch (e) {
      setState(() => message = 'خطأ اتصال: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> saveAndContinue() async {
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
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Text('Nodrix', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('إعداد مصدر الساس وربط التطبيق بالسيرفر. النسخة الحالية تجريبية وتعمل على mock.', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(title: 'إعداد الساس', subtitle: 'اربط التطبيق بالـ Backend ومحول الساس التجريبي', icon: Icons.settings_ethernet),
                      const SizedBox(height: 20),
                      field('رابط السيرفر', serverController, icon: Icons.dns),
                      field('نوع الساس', typeController, icon: Icons.extension),
                      field('رابط الساس', sasUrlController, icon: Icons.link),
                      field('اسم المستخدم', usernameController, icon: Icons.person),
                      field('كلمة المرور', passwordController, secret: true, icon: Icons.lock),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: FilledButton.icon(onPressed: loading ? null : testConnection, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering), label: const Text('اختبار الاتصال'))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: saveAndContinue, icon: const Icon(Icons.login), label: const Text('حفظ ومتابعة'))),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                          child: Text(message),
                        ),
                      ],
                    ],
                  ),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: widget.api),
      CustomersPage(api: widget.api),
      DevicesPage(title: 'السكاترات', icon: Icons.cell_tower, loader: widget.api.getSectors),
      DevicesPage(title: 'اللنكات', icon: Icons.hub, loader: widget.api.getLinks),
      RemindersPage(api: widget.api),
      UpdatesPage(api: widget.api),
    ];
    final titles = ['الرئيسية', 'المشتركين', 'السكاترات', 'اللنكات', 'التنبيهات', 'التحديثات'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: FilledButton.tonalIcon(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh), label: const Text('تحديث')),
          ),
        ],
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
        if (data['ok'] == false) return Center(child: Text(data['message']?.toString() ?? 'السيرفر رفض الطلب'));
        final cards = [
          _Metric('مشترك فعّال', data['activeCustomers'], Icons.verified_user, const Color(0xFF16A34A)),
          _Metric('قريب الانتهاء', data['expiresSoon'], Icons.schedule, const Color(0xFFF59E0B)),
          _Metric('مشترك منتهي', data['expiredCustomers'], Icons.block, const Color(0xFFDC2626)),
          _Metric('الأبراج', data['towers'], Icons.cell_tower, const Color(0xFF2563EB)),
          _Metric('سكاترات متصلة', data['sectorsOnline'], Icons.router, const Color(0xFF0F766E)),
          _Metric('لنكات متصلة', data['linksOnline'], Icons.hub, const Color(0xFF7C3AED)),
          _Metric('دخل اليوم', money(data['incomeToday']), Icons.payments, const Color(0xFF0891B2)),
          _Metric('دخل الشهر', money(data['incomeMonth']), Icons.bar_chart, const Color(0xFF4F46E5)),
          _Metric('تذاكر مفتوحة', data['openTickets'], Icons.confirmation_number, const Color(0xFFEA580C)),
          _Metric('تنبيهات واتساب', data['whatsappDue'], Icons.message, const Color(0xFF22C55E)),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'نظرة عامة', subtitle: 'البيانات الحالية تجريبية. الهيكل جاهز للربط الحقيقي لاحقًا.', icon: Icons.insights),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 650 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 1.55, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemBuilder: (_, i) => MetricCard(metric: cards[i]),
                );
              },
            ),
          ],
        );
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: metric.color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(metric.icon, color: metric.color),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${metric.value}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(metric.label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ]),
          ],
        ),
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
  String query = '';
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: widget.api.getCustomers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في المشتركين: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!.cast<Map<String, dynamic>>();
        final items = all.where((c) {
          final text = '${c['name']} ${c['phone']} ${c['tower']} ${c['sector']} ${c['username']}'.toLowerCase();
          final matchesQuery = query.isEmpty || text.contains(query.toLowerCase());
          final matchesFilter = filter == 'all' || c['status'] == filter;
          return matchesQuery && matchesFilter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'المشتركين', subtitle: 'بحث وفلترة حسب حالة الاشتراك', icon: Icons.people_alt),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم، الهاتف، اليوزر، البرج أو السكتر'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('الكل'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
                ChoiceChip(label: const Text('فعّال'), selected: filter == 'active', onSelected: (_) => setState(() => filter = 'active')),
                ChoiceChip(label: const Text('قريب الانتهاء'), selected: filter == 'expires_soon', onSelected: (_) => setState(() => filter = 'expires_soon')),
                ChoiceChip(label: const Text('منتهي'), selected: filter == 'expired', onSelected: (_) => setState(() => filter = 'expired')),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا يوجد مشتركين مطابقين للبحث.'))),
            ...items.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: CustomerCard(customer: c))),
          ],
        );
      },
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  const CustomerCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 24, child: Text(customer['name'].toString().isEmpty ? '?' : customer['name'].toString().substring(0, 1).toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer['name']?.toString() ?? 'بدون اسم', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('${customer['phone']} • ${customer['username']}', style: TextStyle(color: Colors.grey.shade600), textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
                StatusPill(customer['status']?.toString() ?? ''),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              runSpacing: 10,
              spacing: 10,
              children: [
                InfoChip(Icons.speed, 'الباقة', customer['package']),
                InfoChip(Icons.payments, 'السعر', money(customer['price'])),
                InfoChip(Icons.cell_tower, 'البرج', customer['tower']),
                InfoChip(Icons.router, 'السكتر', customer['sector']),
                InfoChip(Icons.event_available, 'البداية', customer['startedAt']),
                InfoChip(Icons.event_busy, 'الانتهاء', customer['expiresAt']),
              ],
            ),
            const SizedBox(height: 12),
            Text(customer['address']?.toString() ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.receipt_long), label: const Text('دفعة')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.message), label: const Text('رسالة')),
              ],
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text('${value ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class DevicesPage extends StatefulWidget {
  final String title;
  final IconData icon;
  final Future<List<dynamic>> Function() loader;
  const DevicesPage({super.key, required this.title, required this.icon, required this.loader});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: widget.loader(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في ${widget.title}: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!.cast<Map<String, dynamic>>();
        final items = all.where((d) => filter == 'all' || d['status'] == filter).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSectionTitle(title: widget.title, subtitle: 'واجهة فقط حاليًا. فحص الأجهزة الحقيقي في مرحلة لاحقة.', icon: widget.icon),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('الكل'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
              ChoiceChip(label: const Text('متصل'), selected: filter == 'online', onSelected: (_) => setState(() => filter = 'online')),
              ChoiceChip(label: const Text('غير متصل'), selected: filter == 'offline', onSelected: (_) => setState(() => filter = 'offline')),
            ]),
            const SizedBox(height: 16),
            ...items.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DeviceCard(device: d))),
          ],
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final isLink = device.containsKey('from');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isLink ? Icons.hub : Icons.router, color: statusColor(device['status']?.toString() ?? '')),
            const SizedBox(width: 10),
            Expanded(child: Text(device['name']?.toString() ?? 'جهاز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            StatusPill(device['status']?.toString() ?? ''),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoChip(Icons.numbers, 'IP', device['ip']),
            InfoChip(Icons.memory, 'النوع', device['type']),
            if (device['tower'] != null) InfoChip(Icons.cell_tower, 'البرج', device['tower']),
            if (device['clients'] != null) InfoChip(Icons.people, 'العملاء', device['clients']),
            if (device['signal'] != null) InfoChip(Icons.network_check, 'الإشارة', device['signal']),
            if (device['capacity'] != null) InfoChip(Icons.speed, 'السعة', device['capacity']),
            if (device['traffic'] != null) InfoChip(Icons.query_stats, 'الترافيك', device['traffic']),
            InfoChip(Icons.timer, 'مدة التشغيل', device['uptime']),
          ]),
          if (isLink) ...[
            const SizedBox(height: 12),
            Text('${device['from']} ← ${device['to']}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.open_in_browser), label: const Text('فتح')),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.monitor_heart), label: const Text('فحص')),
          ]),
        ]),
      ),
    );
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
  void initState() {
    super.initState();
    future = widget.api.getReminderPreview();
  }

  void refresh() => setState(() => future = widget.api.getReminderPreview());

  Future<void> sendDemo() async {
    final result = await widget.api.sendDemoReminders();
    setState(() => sendResult = '${result['note'] ?? 'تمت المحاكاة'} العدد: ${result['sentCount'] ?? 0}');
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ في التنبيهات: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data['ok'] == false) return Center(child: Text(data['message']?.toString() ?? 'السيرفر رفض الطلب'));
        final reminders = (data['reminders'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'تنبيهات واتساب', subtitle: 'محاكاة فقط. لا يتم إرسال رسائل حقيقية الآن.', icon: Icons.mark_chat_unread),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تنبيهات جاهزة: ${data['count']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('السيرفر يحسب المشتركين المطلوب تنبيههم قبل 72/48/24 ساعة.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  FilledButton.icon(onPressed: sendDemo, icon: const Icon(Icons.send), label: const Text('إرسال تجريبي')),
                  if (sendResult.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                      child: Text(sendResult),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (reminders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تنبيهات مستحقة الآن.'))),
            ...reminders.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.message)),
                  title: Text('${r['name']} - ${r['phone']}', style: const TextStyle(fontWeight: FontWeight.w800), textDirection: TextDirection.ltr),
                  subtitle: Text('ينتهي: ${r['expiresAt']} • الساعات المتبقية: ${r['remainingHours']}\n${r['message']}'),
                ),
              ),
            )),
          ],
        );
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
  void initState() {
    super.initState();
    future = widget.api.getAppVersion();
  }

  void refresh() => setState(() => future = widget.api.getAppVersion());

  Future<void> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط. تم نسخه للحافظة.')));
    }
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
        final latest = data['latestVersion']?.toString() ?? currentAppVersion;
        final apkUrl = data['apkUrl']?.toString() ?? '';
        final notes = data['notes']?.toString() ?? 'لا توجد ملاحظات.';
        final hasUpdate = compareVersions(latest, currentAppVersion) > 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'تحديثات التطبيق', subtitle: 'افحص آخر نسخة وحمّل APK جديد عند الحاجة.', icon: Icons.system_update_alt),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InfoChip(Icons.phone_android, 'نسختك الحالية', currentAppVersion),
                  const SizedBox(height: 10),
                  InfoChip(Icons.cloud_download, 'آخر نسخة', latest),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasUpdate ? Colors.orange.withOpacity(.12) : Colors.green.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(hasUpdate ? 'يوجد تحديث جديد متاح.' : 'أنت تستخدم آخر نسخة متاحة.', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 14),
                  Text('ملاحظات التحديث', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(notes),
                  const SizedBox(height: 14),
                  if (apkUrl.isNotEmpty) ...[
                    SelectableText(apkUrl, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: hasUpdate ? () => openDownload(apkUrl) : null, icon: const Icon(Icons.download), label: const Text('تحميل التحديث'))),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(onPressed: () => copyText(apkUrl), icon: const Icon(Icons.copy), label: const Text('نسخ')),
                    ]),
                  ] else
                    const Text('لم يتم تحديد رابط APK بعد. ضع APP_APK_URL في Railway عند توفر نسخة جديدة.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh), label: const Text('إعادة الفحص')),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ملاحظة: أندرويد سيطلب موافقتك عند تثبيت APK. التحديث الصامت بالكامل يحتاج Google Play أو نظام إدارة أجهزة.'),
              ),
            ),
          ],
        );
      },
    );
  }
}
