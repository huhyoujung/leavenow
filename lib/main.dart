// macOS 메뉴바 앱 진입점
// 주의: .env 파일을 프로젝트 루트에 직접 생성해야 함 (git에 포함되지 않음)
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/repositories/settings_repository.dart';
import 'platforms/macos/menu_bar_app.dart';
import 'platforms/macos/settings_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(420, 280),
    minimumSize: Size(420, 280),
    title: 'LeaveNow 설정',
    center: true,
    skipTaskbar: true,
  );

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs: prefs);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.hide();
  });

  runApp(AppRoot(settings: settings));
}

class AppRoot extends StatefulWidget {
  final SettingsRepository settings;
  const AppRoot({super.key, required this.settings});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            // 메뉴바 앱 (SizedBox.shrink — UI 없음, tray 로직만)
            MenuBarApp(settings: widget.settings),
            // 설정 창 UI
            SettingsWindow(
              settings: widget.settings,
              onSaved: () {
                // 저장 후 MenuBarApp이 tray 갱신 — 별도 콜백 불필요
                // (MenuBarApp은 settings 객체를 직접 참조하므로
                //  다음 _refresh 호출 시 최신 값 반영)
              },
            ),
          ],
        ),
      ),
    );
  }
}
