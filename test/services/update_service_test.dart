import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('自动检查默认启用并保留显式关闭设置', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = UpdateService(prefs: prefs);

    expect(service.getAutoCheckUpdate(), isTrue);

    await service.setAutoCheckUpdate(false);

    expect(UpdateService(prefs: prefs).getAutoCheckUpdate(), isFalse);
  });

  test('解析 FluxIDC 发布标签并按三段版本比较', () {
    expect(
      UpdateService.parseReleaseVersion('v0.2.25-fluxidc.1'),
      '0.2.25',
    );
    expect(UpdateService.parseReleaseVersion('v0.2.26'), '0.2.26');
    expect(
      UpdateService.compareVersions('v0.2.25-fluxidc.1', '0.2.26'),
      lessThan(0),
    );
    expect(
      UpdateService.compareVersions('v0.2.26-fluxidc.2', '0.2.26+2026081501'),
      0,
    );
  });

  test('从 FluxIDC latest release API 读取并配对 APK 校验文件', () async {
    final adapter = _ReleaseAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = UpdateService(
      dio: dio,
      currentVersionLoader: () async => '0.2.26',
    );

    final updateInfo = await service.checkForUpdate();

    expect(UpdateService.repository, 'lmarch2/fluxidc');
    expect(adapter.requestedUrl, UpdateService.apiUrl);
    expect(updateInfo.remoteVersion, '0.2.25');
    expect(updateInfo.hasUpdate, isFalse);
    expect(updateInfo.apkAssets, hasLength(1));
    expect(updateInfo.apkAssets.single.name, 'FluxIDC-0.2.25-arm64-v8a.apk');
    expect(
      updateInfo.apkAssets.single.sha256Url,
      'https://example.test/FluxIDC-0.2.25-arm64-v8a.apk.sha256',
    );
  });
}

class _ReleaseAdapter implements HttpClientAdapter {
  String? requestedUrl;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrl = options.uri.toString();
    return ResponseBody.fromString(
      jsonEncode({
        'tag_name': 'v0.2.25-fluxidc.1',
        'html_url': 'https://github.com/lmarch2/fluxidc/releases/tag/'
            'v0.2.25-fluxidc.1',
        'body': 'FluxIDC release notes',
        'assets': [
          {
            'name': 'FluxIDC-0.2.25-arm64-v8a.apk',
            'browser_download_url':
                'https://example.test/FluxIDC-0.2.25-arm64-v8a.apk',
            'size': 123,
          },
          {
            'name': 'FluxIDC-0.2.25-arm64-v8a.apk.sha256',
            'browser_download_url':
                'https://example.test/FluxIDC-0.2.25-arm64-v8a.apk.sha256',
            'size': 64,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
