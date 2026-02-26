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

  // 타이틀바 없는 고정 크기 패널 (트레이 아이콘 바로 아래에 표시)
  const windowOptions = WindowOptions(
    size: Size(380, 260),
    minimumSize: Size(380, 260),
    maximumSize: Size(380, 260),
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    skipTaskbar: true,
  );

  // tray 타이틀을 runApp() 전에 먼저 설정 → NSStatusItem으로 NSRunLoop 유지
  // setIcon()은 Flutter 엔진 시작 후 MenuBarApp._init()에서 처리
  await trayManager.setTitle('🚌');

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
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

  // 닫기 버튼 / 포커스 잃으면 숨기기 (앱 종료 방지, popover 동작)
  @override
  void onWindowClose() async => windowManager.hide();

  @override
  void onWindowBlur() async => windowManager.hide();

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
