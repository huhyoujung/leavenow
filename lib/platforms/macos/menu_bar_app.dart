// macOS 메뉴바 앱 - 정류장 실시간 버스 도착정보 표시
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/app_controller.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/seoul_bus_service.dart';
import '../../core/services/scenario_service.dart';

class MenuBarApp extends StatefulWidget {
  final SettingsRepository settings;
  const MenuBarApp({super.key, required this.settings});

  @override
  State<MenuBarApp> createState() => _MenuBarAppState();
}

class _MenuBarAppState extends State<MenuBarApp> {
  static const _channel = MethodChannel('com.leavenow/statusbar');
  AppController? _controller;
  bool _manualOverride = false;
  Timer? _arrivalTimer;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onMenuItemClick') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final key = args['key'] as String?;
      switch (key) {
        case 'toggle':
          _manualOverride = true;
          _controller?.toggleScenario();
          await _refresh();
        case 'refresh':
          await _refresh();
        case 'settings':
          _showSettingsWindow();
      }
    }
  }

  Future<void> _setTitle(String title) async {
    try {
      await _channel.invokeMethod('setTitle', {'title': title});
    } catch (_) {}
  }

  Future<void> _setMenu(List<Map<String, dynamic>> items) async {
    try {
      await _channel.invokeMethod('setMenu', {'items': items});
    } catch (_) {}
  }

  Future<void> _init() async {
    final scenario = _manualOverride
        ? _controller?.scenario
        : ScenarioService.detectByTime(
            DateTime.now(),
            thresholdHour: widget.settings.timeThresholdHour,
          );

    _controller = AppController(
      busService: SeoulBusService(dio: Dio()),
      scenario: scenario ?? Scenario.toWork,
      homeArsId: widget.settings.homeArsId ?? '',
      workArsId: widget.settings.workArsId ?? '',
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    if (!widget.settings.isConfigured) {
      await _setTitle('⚙️');
      await _buildContextMenu(isEmpty: true);
      return;
    }

    try {
      await _controller?.refreshArrivals();
    } catch (e) {
      debugPrint('[LEAVENOW] refreshArrivals ERROR: $e');
      await _setTitle('⚠️');
      return;
    }

    await _updateTray();
    _scheduleTimer();
  }

  Future<void> _updateTray() async {
    final controller = _controller;
    if (controller == null) return;

    final now = DateTime.now();
    final upcoming = controller.departures
        .where((d) => d.minutesUntil(now) >= 0)
        .take(2)
        .toList();

    if (upcoming.isEmpty) {
      await _setTitle('🚌—');
    } else {
      final mins = upcoming.map((d) => '${d.minutesUntil(now)}').join('/');
      await _setTitle('🚌${mins}분');
    }

    await _buildContextMenu(isEmpty: false);
  }

  Future<void> _buildContextMenu({required bool isEmpty}) async {
    final controller = _controller;
    final items = <Map<String, dynamic>>[];

    if (isEmpty || controller == null) {
      items.add({'label': '설정이 필요합니다', 'disabled': true});
      items.add({'type': 'separator'});
      items.add({'label': '설정 열기', 'key': 'settings'});
      await _setMenu(items);
      return;
    }

    final currentMode =
        controller.scenario == Scenario.toWork ? '🏢 회사로' : '🏠 집으로';
    final toggleLabel = controller.scenario == Scenario.toWork
        ? '🏠 집으로 전환'
        : '🏢 회사로 전환';

    items.add({'label': '$currentMode  (${controller.currentArsId})', 'disabled': true});
    items.add({'label': toggleLabel, 'key': 'toggle'});
    items.add({'type': 'separator'});

    final now = DateTime.now();
    final upcoming = controller.departures
        .where((d) => d.minutesUntil(now) >= 0)
        .take(10)
        .toList();

    if (upcoming.isEmpty) {
      items.add({'label': '도착 정보 없음', 'disabled': true});
    } else {
      for (final d in upcoming) {
        final min = d.minutesUntil(now);
        items.add({
          'label': '${d.displayLabel}  $min분 후',
          'disabled': true,
        });
      }
    }

    items.add({'type': 'separator'});
    items.add({'label': '새로고침', 'key': 'refresh'});
    items.add({'label': '설정...', 'key': 'settings'});

    await _setMenu(items);
  }

  void _scheduleTimer() {
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(),
    );
  }

  Future<void> _showSettingsWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    super.dispose();
  }
}
