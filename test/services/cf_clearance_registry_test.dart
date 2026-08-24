import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/cf_clearance_registry.dart';
import 'package:fluxdo/services/network/cookie/cookie_value_codec.dart';

/// 「被拒即永拒」墓碑的契约。
///
/// 病灶（2026-08-19 app_log 实锤）：手动 CF 验证通过、retry 200 后 ~1.5s，
/// Turnstile WebView load_stop 把 cookie store 里残留的旧 pre-clearance
/// （CHIPS 分区副本，常规删除清不掉）同步回 jar 覆盖有效值 → 下一次
/// POST /topics/timings 立刻 403 → 再验证 → 再被覆盖，三轮循环分毫不差。
///
/// expires 先后不能作为新旧依据（日志里 expires 更晚的那枚恰是被拒的），
/// 唯一确定性不变量：被 CF 拒过的值永远不会重新有效。登记后任何同步来源
/// 不得再写回 jar。
void main() {
  group('extractFromCookieHeader', () {
    test('从完整 Cookie header 提取 cf_clearance', () {
      expect(
        CfClearanceRegistry.extractFromCookieHeader(
          '_t=token123; cf_clearance=abc.def-_123; _forum_session=sess',
        ),
        'abc.def-_123',
      );
    });

    test('cf_clearance 在开头/结尾/缺失时的提取', () {
      expect(
        CfClearanceRegistry.extractFromCookieHeader('cf_clearance=aaa; _t=x'),
        'aaa',
      );
      expect(
        CfClearanceRegistry.extractFromCookieHeader('_t=x; cf_clearance=zzz'),
        'zzz',
      );
      expect(
        CfClearanceRegistry.extractFromCookieHeader('_t=x; _forum_session=y'),
        isNull,
      );
      expect(CfClearanceRegistry.extractFromCookieHeader(''), isNull);
      expect(CfClearanceRegistry.extractFromCookieHeader(null), isNull);
    });

    test('不误匹配名字后缀相同的 cookie', () {
      expect(
        CfClearanceRegistry.extractFromCookieHeader(
          'my_cf_clearance=bad; _t=x',
        ),
        isNull,
      );
    });
  });

  group('markRejected / isRejected', () {
    test('登记后原值被判为被拒，未登记值不受影响', () {
      final registry = CfClearanceRegistry.instance..reset();
      expect(registry.isRejected('value-a'), isFalse);

      registry.markRejected('value-a');

      expect(registry.isRejected('value-a'), isTrue);
      expect(registry.isRejected('value-b'), isFalse);
      expect(registry.rejectedCount, 1);
    });

    test('编码形态与解码形态互相命中（jar 存储可能带 ~enc~ 前缀编码）', () {
      final registry = CfClearanceRegistry.instance..reset();
      const raw = 'clear{"ace}';
      final encoded = CookieValueCodec.encode(raw);

      // 以解码形态登记，编码形态命中
      registry.markRejected(raw);
      expect(registry.isRejected(encoded), isTrue);

      registry.reset();

      // 以编码形态登记，解码形态命中
      registry.markRejected(encoded);
      expect(registry.isRejected(raw), isTrue);
    });

    test('null / 空值登记为 no-op', () {
      final registry = CfClearanceRegistry.instance..reset();
      registry.markRejected(null);
      registry.markRejected('');
      expect(registry.rejectedCount, 0);
      expect(registry.isRejected(null), isFalse);
      expect(registry.isRejected(''), isFalse);
    });

    test('markRejectedFromCookieHeader 端到端：撞盾请求里发送的值被拉黑', () {
      final registry = CfClearanceRegistry.instance..reset();
      // 模拟撞盾请求（403/429 challenge）当时实际发送的 Cookie 头
      registry.markRejectedFromCookieHeader(
        '_t=token; cf_clearance=stale-value-14_21_18; _forum_session=s',
      );

      // 之后 Turnstile WebView 同步回同一枚残留值 → 同步闸门据此拒绝写回
      expect(registry.isRejected('stale-value-14_21_18'), isTrue);
      // 手动验证新铸的值不在册 → 可正常写回
      expect(registry.isRejected('fresh-value-16_04_58'), isFalse);
    });

    test('reset 清空（登出换账号）', () {
      final registry = CfClearanceRegistry.instance..reset();
      registry.markRejected('value-a');
      expect(registry.rejectedCount, 1);

      registry.reset();

      expect(registry.rejectedCount, 0);
      expect(registry.isRejected('value-a'), isFalse);
    });
  });
}
