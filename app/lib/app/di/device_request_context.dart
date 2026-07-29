import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Supplies the headers every request carries.
///
/// The values are read once and cached: [onRequest] runs on every call, and
/// hitting a platform channel there would add a hop to each request and can
/// deadlock during startup.
@LazySingleton(as: RequestContextProvider)
final class DeviceRequestContext implements RequestContextProvider {
  DeviceRequestContext();

  Map<String, String>? _cached;

  @override
  Future<Map<String, String>> headers() async {
    return _cached ??= await _collect();
  }

  Future<Map<String, String>> _collect() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    // A stable per-install id, not a hardware identifier: `identifierForVendor`
    // and `androidId` reset on reinstall, which is what privacy review expects.
    final (String deviceId, String deviceModel, String osVersion) = await () async {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return (info.id, '${info.manufacturer} ${info.model}', 'Android ${info.version.release}');
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return (info.identifierForVendor ?? 'unknown', info.utsname.machine, 'iOS ${info.systemVersion}');
      }
      return ('unknown', 'unknown', Platform.operatingSystemVersion);
    }();

    return {
      'X-Device-Id': deviceId,
      'X-Device-Model': deviceModel,
      'X-Device-Os': osVersion,
      'X-App-Version': '${packageInfo.version}+${packageInfo.buildNumber}',
      'X-Platform': Platform.operatingSystem,
      'Accept-Language': WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
    };
  }
}
