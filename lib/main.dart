// macOS 메뉴바 앱 진입점
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs: prefs);

  const windowOptions = WindowOptions(
    size: Size(380, 340),
    minimumSize: Size(380, 280),
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    skipTaskbar: true,
  );

  // NSStatusItem은 AppDelegate에서 네이티브로 생성 (tray_manager 미사용)

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
    await windowManager.setAsFrameless();  // 완전히 프레임 없는 창
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
  int _menuBarKey = 0;

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

  // 닫기 버튼 → 숨기기 (앱 종료 방지)
  @override
  void onWindowClose() async => windowManager.hide();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C1C1E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: '.AppleSystemUIFont',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 메뉴바 앱 (SizedBox.shrink — UI 없음, tray 로직만)
            // key가 바뀌면 재생성 → 설정 저장 후 자동 새로고침
            MenuBarApp(key: ValueKey(_menuBarKey), settings: widget.settings),
            // 설정 창 UI
            SettingsWindow(
              settings: widget.settings,
              onSaved: () => setState(() => _menuBarKey++),
            ),
          ],
        ),
      ),
    );
  }
}
