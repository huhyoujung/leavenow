// macOS 메뉴바 앱 진입점
// 주의: .env 파일을 프로젝트 루트에 직접 생성해야 함 (git에 포함되지 않음)
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/repositories/settings_repository.dart';
import 'platforms/macos/menu_bar_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs: prefs);

  runApp(MenuBarApp(settings: settings));
}
