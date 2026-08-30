import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/services/update_service.dart';

void main() {
  test('版本号比较：支持 v 前缀与 +build 后缀，缺失段按 0', () {
    expect(UpdateService.compareVersions('0.2.0', '0.2.0'), 0);
    expect(UpdateService.compareVersions('v0.2.0', '0.2.0'), 0);
    expect(UpdateService.compareVersions('0.2.1', '0.2.0'), greaterThan(0));
    expect(UpdateService.compareVersions('0.1.9', '0.2.0'), lessThan(0));
    expect(UpdateService.compareVersions('0.2', '0.2.0'), 0);
    expect(UpdateService.compareVersions('0.2.0+2', '0.2.0'), 0);
    expect(UpdateService.compareVersions('1.0', '0.9.9'), greaterThan(0));
    expect(UpdateService.compareVersions('V10.0.0', '9.9.9'), greaterThan(0));
  });

  test('版本号归一化', () {
    expect(UpdateService.normalizeVersion(' v0.2.0+3 '), '0.2.0');
    expect(UpdateService.normalizeVersion('1.2.3'), '1.2.3');
  });
}
