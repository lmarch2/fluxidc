import 'package:flutter/foundation.dart';

import 'cf_challenge_logger.dart';
import 'network/cookie/cookie_value_codec.dart';

/// cf_clearance 墓碑登记处（会话级）。
///
/// **不变量：被 CF 明确拒绝（403/429 + challenge）的 clearance 值，永远不会
/// 重新变有效。** 它是单次签发的令牌，失效/被吊销后重发同一个值只会得到
/// 同样的拒绝。
///
/// 这块逻辑反反复复出过的全是同一类病——某个同步路径把被拒/旧的值"复活"
/// 进 jar（e646a23 选错旧份、Bug #5 残留旧值、12b78389 CF 后持续 403、
/// 2026-08-19 日志实锤的 Turnstile WebView 把 CHIPS 分区残留旧副本盖回
/// jar 形成"过一次盾只管一次"循环）。以往每次都在"选优/比 expires"上打
/// 补丁，但 expires 先后不代表签发新旧（challenge page 与 Turnstile 签发
/// 的 TTL 形态不同，2026-08-19 日志里 expires 更晚的那枚恰恰是被拒的）。
/// 墓碑不依赖任何启发式：值一旦被拒，任何同步来源都不得再写回 jar。
///
/// 会话级即可：残留旧副本随 WebView cookie store 生命周期轮换，无需持久化；
/// 登出时 [reset] 清空。
class CfClearanceRegistry {
  CfClearanceRegistry._();
  static final CfClearanceRegistry instance = CfClearanceRegistry._();

  /// 被拒值的集合（原始形态与解码形态都登记，比对时两侧同样归一化）。
  final Set<String> _rejected = <String>{};

  static final RegExp _clearancePattern = RegExp(
    r'(?:^|;\s*)cf_clearance=([^;]*)',
  );

  /// 从请求的 Cookie header 中提取 cf_clearance 值（可能为 null）。
  static String? extractFromCookieHeader(String? cookieHeader) {
    if (cookieHeader == null || cookieHeader.isEmpty) return null;
    final value = _clearancePattern.firstMatch(cookieHeader)?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// 归一化：请求头里的值是 [CookieValueCodec.decode] 后的形态（见
  /// AppCookieManager），WebView 回读的也是解码形态；jar 存储可能带编码。
  /// 两侧统一 decode 一次（cf_clearance 值是 URL-safe 字符，重复 decode 幂等）。
  static String _normalize(String value) => CookieValueCodec.decode(value);

  /// 登记一枚被 CF 拒绝的 clearance（403/429 challenge 时发送的值）。
  void markRejected(String? value) {
    if (value == null || value.isEmpty) return;
    final normalized = _normalize(value);
    if (_rejected.add(normalized)) {
      debugPrint(
        '[CfClearanceRegistry] 登记被拒 cf_clearance '
        '(${normalized.length} chars)，本会话内禁止复活',
      );
      CfChallengeLogger.log(
        '[REGISTRY] cf_clearance tombstoned (${normalized.length} chars), '
        'total=${_rejected.length}',
        level: 'warning',
      );
    }
  }

  /// 从 Cookie header 提取并登记。
  void markRejectedFromCookieHeader(String? cookieHeader) {
    markRejected(extractFromCookieHeader(cookieHeader));
  }

  /// 该值是否已被 CF 拒过（被拒即永拒，任何同步来源不得再写回 jar）。
  bool isRejected(String? value) {
    if (value == null || value.isEmpty) return false;
    return _rejected.contains(_normalize(value));
  }

  /// 当前登记数（诊断用）。
  int get rejectedCount => _rejected.length;

  /// 登出/换账号时清空：值随登录会话签发，新会话的 clearance 与此无关。
  void reset() {
    _rejected.clear();
  }
}
