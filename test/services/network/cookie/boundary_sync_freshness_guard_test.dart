import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/network/cookie/boundary_sync_service.dart';

/// 「防旧盖新」守卫的判定表契约。
///
/// 病灶（2026-08-19 app_log 实锤）：手动 CF 验证通过、retry 200 后 ~1.5s，
/// CfClearanceRefreshService 的 Turnstile WebView 在 load_stop 时把 cookie
/// store 里残留的旧 pre-clearance（CHIPS 分区副本，常规删除清不掉）同步回
/// jar，覆盖刚验证拿到的有效 clearance → 下一次 POST /topics/timings 立刻
/// 403 → 再验证 → 再被覆盖，形成「过一次盾只管一次」的循环。
///
/// 守卫原则：写入 jar 前比对——值相同幂等跳过；值不同但 WebView 这枚的
/// expires 不晚于 jar 当前值 = 旧盖新，拒绝；任一侧 expires 缺失时放行
///（无法证明更旧，保守不挡正常续期）。
void main() {
  group('freshnessOverwriteDecision', () {
    final t1 = DateTime(2026, 8, 26, 14, 21, 18); // 残留旧副本
    final t2 = DateTime(2026, 8, 26, 16, 5, 0); // 手动验证新签发
    final t3 = DateTime(2027, 8, 19, 16, 5, 18); // Turnstile 后续新签

    test('jar 无值时放行（首次写入）', () {
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: null,
          jarExpires: null,
          webViewValue: 'c0',
          webViewExpires: t1,
        ),
        FreshnessOverwrite.allow,
      );
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: '',
          jarExpires: null,
          webViewValue: 'c0',
          webViewExpires: t1,
        ),
        FreshnessOverwrite.allow,
      );
    });

    test('值相同幂等跳过（无论 expires 先后）', () {
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'c1',
          jarExpires: t2,
          webViewValue: 'c1',
          webViewExpires: t2,
        ),
        FreshnessOverwrite.skipSameValue,
      );
    });

    test('值不同且 WebView expires 早于 jar = 旧盖新，拒绝（病灶场景）', () {
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'manual-verify-clearance',
          jarExpires: t2, // 手动验证 16:05 签发
          webViewValue: 'stale-preclearance',
          webViewExpires: t1, // 残留旧副本 14:21 签发
        ),
        FreshnessOverwrite.skipStale,
      );
    });

    test('值不同且 expires 相同也拒绝（不晚于即拒绝）', () {
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'c1',
          jarExpires: t2,
          webViewValue: 'c0',
          webViewExpires: t2,
        ),
        FreshnessOverwrite.skipStale,
      );
    });

    test('值不同但 WebView expires 更晚 = 正常续期，放行', () {
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'manual-verify-clearance',
          jarExpires: t2,
          webViewValue: 'turnstile-new-clearance',
          webViewExpires: t3, // Turnstile 新签，expires 更晚
        ),
        FreshnessOverwrite.allow,
      );
    });

    test('任一侧 expires 缺失时放行（保守不挡正常同步）', () {
      // jar 是 session cookie 形态（无 expires）
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'c1',
          jarExpires: null,
          webViewValue: 'c0',
          webViewExpires: t1,
        ),
        FreshnessOverwrite.allow,
      );
      // WebView 读不到 expires
      expect(
        BoundarySyncService.freshnessOverwriteDecision(
          jarValue: 'c1',
          jarExpires: t2,
          webViewValue: 'c0',
          webViewExpires: null,
        ),
        FreshnessOverwrite.allow,
      );
    });
  });
}
