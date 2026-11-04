import 'package:flutter_test/flutter_test.dart';
import 'package:opnsense_network_monitor/main.dart';

void main() {
  group('Device.fromJson', () {
    test('parses online device fields and latency', () {
      final device = Device.fromJson({
        'hostname': 'Router',
        'ip': '192.168.1.1',
        'mac': 'AA:BB:CC:DD:EE:FF',
        'description': 'Gateway',
        'network': 'LAN',
        'online': true,
        'latency_ms': 2.5,
      });

      expect(device.hostname, 'Router');
      expect(device.ip, '192.168.1.1');
      expect(device.mac, 'AA:BB:CC:DD:EE:FF');
      expect(device.description, 'Gateway');
      expect(device.network, 'LAN');
      expect(device.online, isTrue);
      expect(device.latency, 2.5);
    });

    test('uses defaults when optional fields are absent', () {
      final device = Device.fromJson({'online': false});

      expect(device.hostname, 'Unknown device');
      expect(device.ip, '');
      expect(device.mac, '');
      expect(device.description, '');
      expect(device.network, 'Other');
      expect(device.online, isFalse);
      expect(device.latency, isNull);
    });
  });
}
