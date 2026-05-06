import 'package:flutter/material.dart';
import 'services/api_service.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
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
  return '${buffer.toString()} IQD';
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
      return 'Active';
    case 'expires_soon':
      return 'Expires soon';
    case 'expired':
      return 'Expired';
    case 'online':
      return 'Online';
    case 'offline':
      return 'Offline';
    default:
      return status;
  }
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
  final serverController = TextEditingController(text: 'http://localhost:3000');
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
      message = 'Testing connection...';
    });

    try {
      final result = await api.testConnection(
        type: typeController.text.trim(),
        sasUrl: sasUrlController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
      setState(() => message = result['message']?.toString() ?? 'Done');
    } catch (e) {
      setState(() => message = 'Connection error: $e');
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
      setState(() => message = 'Save error: $e');
    }
  }

  Widget field(String label, TextEditingController controller, {bool secret = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
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
              Text('Setup the SAS source. For web testing use localhost. For Android emulator use 10.0.2.2.', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(title: 'SAS Setup', subtitle: 'Connect the app to backend and demo SAS adapter', icon: Icons.settings_ethernet),
                      const SizedBox(height: 20),
                      field('Backend URL', serverController, icon: Icons.dns),
                      field('SAS Type', typeController, icon: Icons.extension),
                      field('SAS URL', sasUrlController, icon: Icons.link),
                      field('Username', usernameController, icon: Icons.person),
                      field('Password', passwordController, secret: true, icon: Icons.lock),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: FilledButton.icon(onPressed: loading ? null : testConnection, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering), label: const Text('Test Connection'))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: saveAndContinue, icon: const Icon(Icons.login), label: const Text('Save and Continue'))),
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
      DevicesPage(title: 'Sectors', icon: Icons.cell_tower, loader: widget.api.getSectors),
      DevicesPage(title: 'Links', icon: Icons.hub, loader: widget.api.getLinks),
      RemindersPage(api: widget.api),
    ];
    final titles = ['Dashboard', 'Customers', 'Sectors', 'Links', 'Reminders'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.cell_tower_outlined), selectedIcon: Icon(Icons.cell_tower), label: 'Sectors'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Links'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Reminders'),
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
        if (snapshot.hasError) return Center(child: Text('Dashboard error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final cards = [
          _Metric('Active customers', data['activeCustomers'], Icons.verified_user, const Color(0xFF16A34A)),
          _Metric('Expires soon', data['expiresSoon'], Icons.schedule, const Color(0xFFF59E0B)),
          _Metric('Expired', data['expiredCustomers'], Icons.block, const Color(0xFFDC2626)),
          _Metric('Towers', data['towers'], Icons.cell_tower, const Color(0xFF2563EB)),
          _Metric('Sectors online', data['sectorsOnline'], Icons.router, const Color(0xFF0F766E)),
          _Metric('Links online', data['linksOnline'], Icons.hub, const Color(0xFF7C3AED)),
          _Metric('Today income', money(data['incomeToday']), Icons.payments, const Color(0xFF0891B2)),
          _Metric('Month income', money(data['incomeMonth']), Icons.bar_chart, const Color(0xFF4F46E5)),
          _Metric('Open tickets', data['openTickets'], Icons.confirmation_number, const Color(0xFFEA580C)),
          _Metric('WhatsApp due', data['whatsappDue'], Icons.message, const Color(0xFF22C55E)),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'Network overview', subtitle: 'Mock data now. UI structure ready for real integrations later.', icon: Icons.insights),
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
        if (snapshot.hasError) return Center(child: Text('Customers error: ${snapshot.error}'));
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
            const AppSectionTitle(title: 'Customers', subtitle: 'Search, status filter, and cleaner customer cards', icon: Icons.people_alt),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, phone, username, tower, sector'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
                ChoiceChip(label: const Text('Active'), selected: filter == 'active', onSelected: (_) => setState(() => filter = 'active')),
                ChoiceChip(label: const Text('Expires soon'), selected: filter == 'expires_soon', onSelected: (_) => setState(() => filter = 'expires_soon')),
                ChoiceChip(label: const Text('Expired'), selected: filter == 'expired', onSelected: (_) => setState(() => filter = 'expired')),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No customers match your search.'))),
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
                      Text(customer['name']?.toString() ?? 'No name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('${customer['phone']} • ${customer['username']}', style: TextStyle(color: Colors.grey.shade600)),
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
                InfoChip(Icons.speed, 'Package', customer['package']),
                InfoChip(Icons.payments, 'Price', money(customer['price'])),
                InfoChip(Icons.cell_tower, 'Tower', customer['tower']),
                InfoChip(Icons.router, 'Sector', customer['sector']),
                InfoChip(Icons.event_available, 'Started', customer['startedAt']),
                InfoChip(Icons.event_busy, 'Expires', customer['expiresAt']),
              ],
            ),
            const SizedBox(height: 12),
            Text(customer['address']?.toString() ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.receipt_long), label: const Text('Payment')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.message), label: const Text('Message')),
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
        if (snapshot.hasError) return Center(child: Text('${widget.title} error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!.cast<Map<String, dynamic>>();
        final items = all.where((d) => filter == 'all' || d['status'] == filter).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSectionTitle(title: widget.title, subtitle: 'Current UI only. Real device checks will come later.', icon: widget.icon),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('All'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
              ChoiceChip(label: const Text('Online'), selected: filter == 'online', onSelected: (_) => setState(() => filter = 'online')),
              ChoiceChip(label: const Text('Offline'), selected: filter == 'offline', onSelected: (_) => setState(() => filter = 'offline')),
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
            Expanded(child: Text(device['name']?.toString() ?? 'Device', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            StatusPill(device['status']?.toString() ?? ''),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoChip(Icons.numbers, 'IP', device['ip']),
            InfoChip(Icons.memory, 'Type', device['type']),
            if (device['tower'] != null) InfoChip(Icons.cell_tower, 'Tower', device['tower']),
            if (device['clients'] != null) InfoChip(Icons.people, 'Clients', device['clients']),
            if (device['signal'] != null) InfoChip(Icons.network_check, 'Signal', device['signal']),
            if (device['capacity'] != null) InfoChip(Icons.speed, 'Capacity', device['capacity']),
            if (device['traffic'] != null) InfoChip(Icons.query_stats, 'Traffic', device['traffic']),
            InfoChip(Icons.timer, 'Uptime', device['uptime']),
          ]),
          if (isLink) ...[
            const SizedBox(height: 12),
            Text('${device['from']} → ${device['to']}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.open_in_browser), label: const Text('Open')), 
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.monitor_heart), label: const Text('Check')),
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
    setState(() => sendResult = '${result['note']} Sent count: ${result['sentCount']}');
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Reminders error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final reminders = (data['reminders'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppSectionTitle(title: 'WhatsApp reminders', subtitle: 'Demo preview only. No real WhatsApp messages are sent.', icon: Icons.mark_chat_unread),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ready reminders: ${data['count']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('The backend calculates customers due for 72/48/24 hour reminders.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  FilledButton.icon(onPressed: sendDemo, icon: const Icon(Icons.send), label: const Text('Send Demo Reminders')),
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
            if (reminders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No reminders are due right now.'))),
            ...reminders.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.message)),
                  title: Text('${r['name']} - ${r['phone']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Expires: ${r['expiresAt']} • Remaining hours: ${r['remainingHours']}\n${r['message']}'),
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}
