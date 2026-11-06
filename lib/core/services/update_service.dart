import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/update/update_page.dart';

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String? changelog;
  final bool forceUpdate;

  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.changelog,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionName: json['version_name'] as String? ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      apkUrl: json['apk_url'] as String? ?? '',
      changelog: json['changelog'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      if (!Platform.isAndroid) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await Supabase.instance.client
          .from('app_versions')
          .select()
          .eq('platform', 'android')
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final remoteUpdate = UpdateInfo.fromJson(response);

      if (remoteUpdate.versionCode > currentBuildNumber) {
        return remoteUpdate;
      }

      return null;
    } catch (e) {
      debugPrint("UpdateService: Erro ao checar atualização: $e");
      return null;
    }
  }

  static Future<void> checkForUpdateAndPrompt(BuildContext context) async {
    try {
      final updateInfo = await checkForUpdate();
      if (updateInfo == null) return;

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UpdatePage(updateInfo: updateInfo),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      debugPrint("UpdateService: Erro ao mostrar popup de atualização: $e");
    }
  }
}

