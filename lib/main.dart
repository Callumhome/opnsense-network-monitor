import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF20E58A);
const bg = Color(0xFF071016);
const panel = Color(0xFF101D26);
const muted = Color(0xFF91A5B3);
const red = Color(0xFFFF6478);
const blue = Color(0xFF54C8FF);

void main() => runApp(const NetworkMonitorApp());

class NetworkMonitorApp extends StatelessWidget {
  const NetworkMonitorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Network Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(
            primary: green,
            surface: panel,
            secondary: blue,
          ),
          cardTheme: CardThemeData(
            color: panel,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF263945)),
            ),
          ),
        ),
        home: const MonitorHome(),
      );
}

class Device {
  final String hostname, ip, mac, description, network;
  final bool online;
  final double? latency;

  Device.fromJson(Map<String, dynamic> j)
      : hostname = '${j['hostname'] ?? 'Unknown device'}',
        ip = '${j['ip'] ?? ''}',
        mac = '${j['mac'] ?? ''}',
        description = '${j['description'] ?? ''}',
        network = '${j['network'] ?? 'Other'}',
        online = j['online'] == true,
        latency = j['latency_ms'] is num
            ? (j['latency_ms'] as num).toDouble()
            : null;
}

class MonitorHome extends StatefulWidget {
  const MonitorHome({super.key});

  @override
  State<MonitorHome> createState() => _MonitorHomeState();
}

class _MonitorHomeState extends State<MonitorHome> {
  String baseUrl = '';
  String filter = 'All networks';
  String query = '';
  List<Device> devices = [];
  bool loading = false;
  String? error;
  int tab = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  Future<void> _loadUrl() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString('backend_url') ?? baseUrl;
    if (mounted) setState(() {});
    refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/devices'))
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final list = (json['devices'] as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          devices = list;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  List<Device> get visible {
    final result = devices.where((d) {
      final net = filter == 'All networks' || d.network == filter;
      final q = query.toLowerCase();

      final match = q.isEmpty ||
          d.hostname.toLowerCase().contains(q) ||
          d.ip.contains(q) ||
          d.mac.toLowerCase().contains(q);

      return net && match;
    }).toList();

    result.sort((a, b) {
      final ipA = a.ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final ipB = b.ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 4; i++) {
        final c = ipA[i].compareTo(ipB[i]);
        if (c != 0) return c;
      }

      return 0;
    });

    return result;
  }

  int get online => devices.where((d) => d.online).length;
  int get offline => devices.length - online;

  int get health =>
      devices.isEmpty ? 0 : (online * 100 / devices.length).round();

  int networkTotal(String name) =>
      devices.where((d) => d.network == name).length;

  int networkOnline(String name) =>
      devices.where((d) => d.network == name && d.online).length;

  Future<void> settings() async {
    final controller = TextEditingController(text: baseUrl);

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend settings'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Backend URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().replaceAll(RegExp(r'/$'), ''),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != null && saved.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString('backend_url', saved);

      setState(() => baseUrl = saved);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: green,
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),

              if (loading)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: panel,
                    color: green,
                  ),
                ),

              if (error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _panel(
                      child: Text(
                        'Connection error\n$error',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  ),
                ),

              if (tab == 0) ...[
                SliverToBoxAdapter(child: _overview()),
                SliverToBoxAdapter(child: _searchAndFilters()),
                SliverToBoxAdapter(
                  child: _sectionTitle(
                    'Connected devices',
                    '${visible.length} devices',
                  ),
                ),
                _deviceList(visible.take(8).toList()),
                SliverToBoxAdapter(
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => tab = 1),
                      child: const Text('View all devices  →'),
                    ),
                  ),
                ),
              ] else if (tab == 1) ...[
                SliverToBoxAdapter(child: _searchAndFilters()),
                SliverToBoxAdapter(
                  child: _sectionTitle('All devices', '${visible.length} devices'),
                ),
                _deviceList(visible),
              ] else if (tab == 2) ...[
                SliverToBoxAdapter(child: _insights()),
              ] else ...[
                SliverToBoxAdapter(child: _alerts()),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Text(
                    'AUTO-REFRESH • 30 SECONDS\n$baseUrl',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: muted,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF063D2A),
                border: Border.all(color: green.withOpacity(.5)),
              ),
              child: const Icon(Icons.router_rounded, color: green, size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Network Monitor',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'OPNsense DHCP  •  Network Overview',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => tab = 3),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            IconButton(
              onPressed: settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      );

  Widget _overview() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: green.withOpacity(.35)),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF063B2A),
                    Color(0xFF101D26),
                    Color(0xFF0B1720),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: green.withOpacity(.12),
                      border: Border.all(color: green, width: 3),
                      boxShadow: [
                        BoxShadow(color: green.withOpacity(.18), blurRadius: 18),
                      ],
                    ),
                    child: Icon(
                      offline == 0
                          ? Icons.check_rounded
                          : Icons.monitor_heart_outlined,
                      color: green,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offline == 0
                              ? 'Network Healthy'
                              : 'Network Monitoring',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offline == 0
                              ? 'All systems operational'
                              : '$offline devices currently offline',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.waves_rounded, color: green, size: 25),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Devices',
                    '${devices.length}',
                    Icons.devices_rounded,
                    blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    'Online',
                    '$online',
                    Icons.wifi_rounded,
                    green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Offline',
                    '$offline',
                    Icons.wifi_off_rounded,
                    red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    'Online rate',
                    '$health%',
                    Icons.signal_cellular_alt_rounded,
                    green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('Networks', 'VIEW ALL  →'),
            Row(
              children: [
                Expanded(
                  child: _networkCard(
                    'Legacy LAN',
                    '192.168.1.0/24',
                    Icons.hub_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _networkCard(
                    'New LAN',
                    '192.168.10.0/24',
                    Icons.hub_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ),
      );

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: panel,
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: color.withOpacity(.12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: const TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _networkCard(String name, String subnet, IconData icon) {
    final total = networkTotal(name);
    final up = networkOnline(name);
    final ratio = total == 0 ? 0.0 : up / total;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: panel,
        border: Border.all(color: const Color(0xFF263945)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: green, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subnet, style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 10),
          Text('$up / $total online', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: green,
              backgroundColor: const Color(0xFF263945),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: muted),
                hintText: 'Search hostname, IP or MAC',
                hintStyle: const TextStyle(color: muted, fontSize: 13),
                filled: true,
                fillColor: panel,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFF263945)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFF263945)),
                ),
              ),
            ),
            const SizedBox(height: 11),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All networks', 'Legacy LAN', 'New LAN', 'Other']
                    .map((name) {
                  final selected = filter == name;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (_) => setState(() => filter = name),
                      selectedColor: const Color(0xFF064D31),
                      backgroundColor: panel,
                      side: BorderSide(
                        color: selected ? green : const Color(0xFF263945),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? green : Colors.white,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title, String trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 10,
                color: muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _deviceList(List<Device> list) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(
            child: Text(
              devices.isEmpty
                  ? 'No devices loaded yet.'
                  : 'No matching devices found.',
              style: const TextStyle(color: muted),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _deviceCard(list[index]),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _deviceCard(Device d) {
    final color = d.online ? green : red;

    final name = d.hostname.toLowerCase();

    final icon = name.contains('ap')
        ? Icons.wifi_rounded
        : name.contains('tv')
            ? Icons.tv_rounded
            : name.contains('nas') ||
                    name.contains('server') ||
                    name.contains('r720')
                ? Icons.dns_rounded
                : Icons.devices_other_rounded;

    return InkWell(
      onTap: () => _showDeviceDetails(d),
      borderRadius: BorderRadius.circular(17),
      child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: d.online ? const Color(0xFF263945) : red.withOpacity(.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withOpacity(.10),
            ),
            child: Icon(
              icon,
              color: d.online ? const Color(0xFFB8C8D1) : red,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.hostname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${d.ip}  •  ${d.network}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.online ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                d.latency == null ? '—' : '${d.latency!.toStringAsFixed(1)} ms',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right_rounded, color: muted, size: 20),
        ],
      ),
    ));
  }

  void _showDeviceDetails(Device d) {
    final color = d.online ? green : red;

    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withOpacity(.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      d.online ? Icons.devices_rounded : Icons.wifi_off_rounded,
                      color: color,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.hostname,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          d.online ? 'Device online' : 'Device offline',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'DEVICE INFORMATION',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('IP address', d.ip, Icons.lan_rounded),
              _detailRow('MAC address', d.mac, Icons.fingerprint_rounded),
              _detailRow('Network', d.network, Icons.hub_rounded),
              _detailRow(
                'Response time',
                d.latency == null
                    ? 'Unavailable'
                    : '${d.latency!.toStringAsFixed(1)} ms',
                Icons.speed_rounded,
              ),
              _detailRow(
                'Description',
                d.description.isEmpty ? 'No description' : d.description,
                Icons.info_outline_rounded,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh device status'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF064D31),
                    foregroundColor: green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: muted)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _insights() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Insights',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'A live snapshot of your network.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 18),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network availability',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$health%',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: health / 100,
                      minHeight: 9,
                      color: green,
                      backgroundColor: const Color(0xFF263945),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$online devices responding out of ${devices.length}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _panel(
              child: Column(
                children: [
                  _insightRow(
                    'Legacy LAN',
                    networkOnline('Legacy LAN'),
                    networkTotal('Legacy LAN'),
                  ),
                  const Divider(color: Color(0xFF263945), height: 24),
                  _insightRow(
                    'New LAN',
                    networkOnline('New LAN'),
                    networkTotal('New LAN'),
                  ),
                  const Divider(color: Color(0xFF263945), height: 24),
                  _insightRow(
                    'Other networks',
                    networkOnline('Other'),
                    networkTotal('Other'),
                  ),                ],
              ),
            ),
            const SizedBox(height: 12),
            _panel(
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, color: blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Average response time',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _averageLatency(),
                          style: const TextStyle(
                            color: blue,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String _averageLatency() {
    final values = devices
        .where((d) => d.online && d.latency != null)
        .map((d) => d.latency!)
        .toList();

    if (values.isEmpty) return 'Not available';

    final avg = values.reduce((a, b) => a + b) / values.length;
    return '${avg.toStringAsFixed(1)} ms';
  }

  Widget _insightRow(String name, int up, int total) => Row(
        children: [
          const Icon(Icons.hub_rounded, color: green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$up / $total online',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      );

  Widget _alerts() {
    final down = devices.where((d) => !d.online).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${down.length} devices currently not responding',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 18),
          if (down.isEmpty)
            _panel(
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: green),
                  SizedBox(width: 10),
                  Text('No offline devices. All clear!'),
                ],
              ),
            ),
          ...down.map((d) => _deviceCard(d)),
          if (down.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Offline status is based on the latest ping. Alert history and push notifications can be added next.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF263945)),
        ),
        child: child,
      );

  Widget _bottomNav() => NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFF0B151D),
        indicatorColor: const Color(0xFF063D2A),
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_rounded),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            label: 'Alerts',
          ),
        ],
      );
}