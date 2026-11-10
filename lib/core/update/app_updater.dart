import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A newer Android build published on GitHub Releases.
class AppUpdate {
  final String version;
  final int build;
  final bool required;
  final String notes;
  final String url;
  final String? sha256;

  const AppUpdate({
    required this.version,
    required this.build,
    required this.required,
    required this.notes,
    required this.url,
    this.sha256,
  });
}

class AppUpdater {
  AppUpdater._();

  /// Always resolves to the `version.json` asset of the newest release.
  static const manifestUrl =
      'https://github.com/Linaxme/hisab_app/releases/latest/download/version.json';

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns the newer build for this device, or null when up to date.
  /// Play Store installs are left to Play, which forbids self-updating.
  static Future<AppUpdate?> check() async {
    if (!isAndroid) return null;
    final info = await PackageInfo.fromPlatform();
    if (info.installerStore == 'com.android.vending') return null;

    // Split-per-ABI APKs carry `abi * 1000 + build` as their version code.
    final current = (int.tryParse(info.buildNumber) ?? 0) % 1000;

    final response = await http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Update manifest: HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final build = (json['build'] as num).toInt();
    if (build <= current) return null;

    final apks = (json['apks'] as Map).cast<String, dynamic>();
    final abi = await OtaUpdate().getAbi();
    final apk = (apks[abi] ?? apks['arm64-v8a'] ?? apks.values.first) as Map;
    return AppUpdate(
      version: json['version'] as String,
      build: build,
      required: current < ((json['minBuild'] as num?)?.toInt() ?? 0),
      notes: (json['notes'] as String?)?.trim() ?? '',
      url: apk['url'] as String,
      sha256: apk['sha256'] as String?,
    );
  }
}

/// Checked once per app start; failures (offline etc.) just mean no prompt.
final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  try {
    return await AppUpdater.check();
  } catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  }
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
