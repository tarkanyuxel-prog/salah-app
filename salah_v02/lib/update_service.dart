import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdater {
  static const _latestRelease = 'https://api.github.com/repos/tarkanyuxel-prog/salah-app/releases/latest';
  static Future<void> check(BuildContext context, {bool silent = true}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http.get(Uri.parse(_latestRelease), headers: const {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) { if (!silent && context.mounted) _message(context, 'Güncelleme kontrol edilemedi.'); return; }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), '');
      final current = info.version;
      final assets = (data['assets'] as List? ?? const []);
      Map<String, dynamic>? apk;
      for (final item in assets) { final asset = item as Map<String, dynamic>; if ((asset['name'] ?? '').toString().toLowerCase().endsWith('.apk')) { apk = asset; break; } }
      if (latest.isEmpty || !_newer(latest, current) || apk == null) { if (!silent && context.mounted) _message(context, 'Salah güncel: v' + current); return; }
      if (!context.mounted) return;
      final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Yeni sürüm: v' + latest), content: Text('Salah v' + current + ' kullanıyorsunuz. v' + latest + ' indirilmeye hazır.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Daha sonra')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Güncelle'))]));
      if (accepted != true || !context.mounted) return;
      _message(context, 'Güncelleme indiriliyor…');
      final url = (apk['browser_download_url'] ?? '').toString();
      final download = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
      if (download.statusCode != 200) throw Exception('APK indirilemedi');
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/salah-v' + latest + '.apk');
      await file.writeAsBytes(download.bodyBytes, flush: true);
      await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    } catch (_) { if (!silent && context.mounted) _message(context, 'Güncelleme sırasında hata oluştu.'); }
  }
  static bool _newer(String remote, String local) {
    List<int> parts(String value) => value.split('+').first.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    final a = parts(remote), b = parts(local); final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) { final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0; if (x != y) return x > y; } return false;
  }
  static void _message(BuildContext context, String text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
}
