// macOS 메뉴바 앱 진입점
// 주의: config.env 파일을 프로젝트 루트에 직접 생성해야 함 (git에 포함되지 않음)
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'core/repositories/settings_repository.dart';
import 'platforms/macos/menu_bar_app.dart';
import 'platforms/macos/settings_window.dart';

void main() {
  // ReceivePort로 Dart isolate를 살린다 (창 숨김 시에도 종료 방지)
  // listen()을 호출해야 release tree-shaking에서 제거되지 않음
  ReceivePort().listen((_) {});

  runZonedGuarded(() async {
    await _main();
  }, (error, stack) {
    // ignore: avoid_print
    print('[LEAVENOW] ERROR: $error\n$stack');
  });
}

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'config.env');
  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs: prefs);

  const windowOptions = WindowOptions(
    size: Size(420, 360),
    minimumSize: Size(420, 360),
    title: 'LeaveNow 설정',
    center: true,
    skipTaskbar: true,
  );

  // tray 아이콘을 runApp() 전에 먼저 설정 → NSStatusItem으로 NSRunLoop 유지
  // (설정 없이 runApp()만 하면 VSYNC 없이 앱이 즉시 종료됨)
  await trayManager.setIcon('assets/tray_icon.png');
  await trayManager.setTitle('🚌');

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    // 창 숨기기는 AppRoot.initState에서 처리
  });

  runApp(AppRoot(settings: settings));
}

class AppRoot extends StatefulWidget {
  final SettingsRepository settings;
  const AppRoot({super.key, required this.settings});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // 창 닫기 버튼 → 닫지 않고 숨기기 (앱 종료 방지)
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

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
              onSaved: () {},
            ),
          ],
        ),
      ),
    );
  }
}
