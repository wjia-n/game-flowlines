import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowlines/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'flowlinesstar'});
    expect(StoreService.starId, 'flowlinesstar');
  });
  test('Android maps to coffee + chocolate', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'flowlinescoffee', 'flowlineschocolate'});
  });
  test('iOS and Android product sets do not overlap', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS)
        .intersection(StoreService.productIdsFor(TargetPlatform.android)), isEmpty);
  });
}
