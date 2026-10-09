import 'package:flutter_test/flutter_test.dart';
import 'package:flowlines/services/settings_service.dart';

void main() {
  group('player name persistence', () {
    test('encode/decode round-trips as one JSON string', () {
      const names = ['Wajiha'];
      final raw = FlowSettings.encodePlayerNames(names);
      expect(raw.startsWith('['), true);
      expect(FlowSettings.decodePlayerNames(raw), names);
    });

    test('corrupt or missing data falls back to defaults', () {
      expect(FlowSettings.decodePlayerNames(null),
          FlowSettings.defaultNames);
      expect(FlowSettings.decodePlayerNames('not-json'),
          FlowSettings.defaultNames);
      expect(FlowSettings.decodePlayerNames('[]'),
          FlowSettings.defaultNames);
    });

    test('blank names fall back to the default', () {
      expect(FlowSettings.decodePlayerNames('["  "]'),
          FlowSettings.defaultNames);
    });

    test('order is preserved (the StringSet bug this replaces)', () {
      const names = ['Zara', 'Ali', 'Mina'];
      final raw = FlowSettings.encodePlayerNames(names);
      expect(FlowSettings.decodePlayerNames(raw), names);
    });
  });
}
