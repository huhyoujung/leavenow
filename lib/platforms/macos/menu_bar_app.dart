// macOS 메뉴바 앱 - tray_manager로 출퇴근 버스/지하철 정보 표시
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/app_controller.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/naver_geocoding_service.dart';
import '../../core/services/odsay_transit_service.dart';
import '../../core/services/scenario_service.dart';

class MenuBarApp extends StatefulWidget {
  final SettingsRepository settings;
  const MenuBarApp({super.key, required this.settings});

  @override
  State<MenuBarApp> createState() => _MenuBarAppState();
}

class _MenuBarAppState extends State<MenuBarApp> with TrayListener {
  AppController? _controller;
  bool _manualOverride = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    // tray 아이콘은 main()에서 이미 설정됨 - 여기선 타이틀만 갱신
    await trayManager.setTitle('🚌 ...');
    await _initController();
  }

  Future<void> _initController() async {
    final scenario = await _detectScenario();
    final dio = Dio();

    _controller = AppController(
      transitService: OdsayTransitService.fromEnv(dio: dio),
      geocodingService: NaverGeocodingService.fromEnv(dio: dio),
      scenario: scenario,
      homeAddress: widget.settings.homeAddress ?? '',
      workAddress: widget.settings.workAddress ?? '',
      preferredRouteId: widget.settings.preferredRouteId,
    );
    await _refresh();
  }

  Future<Scenario> _detectScenario() async {
    if (!_manualOverride) {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        // GPS 좌표를 가져오지만, 집/회사 좌표 설정 전까지 시간 기반으로 폴백
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        );
      } catch (_) {
        // 위치 권한 거부 또는 오류 → 시간 기반으로 폴백
      }
    }
    return ScenarioService.detectByTime(
      DateTime.now(),
      thresholdHour: widget.settings.timeThresholdHour,
    );
  }

  Future<void> _refresh() async {
    if (!widget.settings.isConfigured) {
      await trayManager.setTitle('⚙️ 설정 필요');
      await _buildContextMenu(isEmpty: true);
      return;
    }

    try {
      await _controller?.loadRoutes();
    } catch (_) {
      await trayManager.setTitle('🚌 오류');
      return;
    }

    await _updateTray();
    _scheduleNextRefresh();
  }

  Future<void> _updateTray() async {
    final controller = _controller;
    if (controller == null) return;

    final preferred = controller.preferredRoute;
    if (preferred == null) {
      await trayManager.setTitle('운행 없음');
      return;
    }

    final now = DateTime.now();
    final upcoming = preferred.upcomingDepartures(now, limit: 1);
    if (upcoming.isEmpty) {
      await trayManager.setTitle('운행 종료');
    } else {
      final next = upcoming.first;
      await trayManager.setTitle(
        '${next.displayLabel}  ${next.minutesUntil(now)}분',
      );
    }

    await _buildContextMenu(isEmpty: false);
  }

  Future<void> _buildContextMenu({required bool isEmpty}) async {
    final controller = _controller;
    final items = <MenuItem>[];

    if (isEmpty || controller == null) {
      items.add(MenuItem(label: '설정이 필요합니다', disabled: true));
      items.add(MenuItem.separator());
      items.add(MenuItem(label: '설정 열기', key: 'settings'));
      await trayManager.setContextMenu(Menu(items: items));
      return;
    }

    final scenarioLabel =
        controller.scenario == Scenario.toWork ? '출근 중' : '퇴근 중';
    final toggleLabel = controller.scenario == Scenario.toWork
        ? '↔ 퇴근 모드로 전환'
        : '↔ 출근 모드로 전환';

    items.add(MenuItem(label: scenarioLabel, disabled: true));
    items.add(MenuItem(label: toggleLabel, key: 'toggle'));
    items.add(MenuItem.separator());

    final now = DateTime.now();
    final preferred = controller.preferredRoute;

    if (preferred != null) {
      items.add(MenuItem(label: '★ 대표 루트', disabled: true));
      for (final d in preferred.upcomingDepartures(now)) {
        items.add(MenuItem(
          label: '${d.displayLabel}   ${d.minutesUntil(now)}분 후',
          disabled: true,
        ));
      }
    }

    final others =
        controller.routes.where((r) => r.id != preferred?.id).toList();
    if (others.isNotEmpty) {
      items.add(MenuItem.separator());
      items.add(MenuItem(label: '기타 루트', disabled: true));
      for (final route in others) {
        final next = route.upcomingDepartures(now, limit: 1);
        if (next.isNotEmpty) {
          items.add(MenuItem(
            label: '${next.first.displayLabel}   ${next.first.minutesUntil(now)}분 후',
            disabled: true,
          ));
        }
      }
    }

    items.add(MenuItem.separator());
    items.add(MenuItem(label: '새로고침', key: 'refresh'));
    items.add(MenuItem(label: '설정', key: 'settings'));

    await trayManager.setContextMenu(Menu(items: items));
  }

  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    // 2분마다 갱신 (TODO: 다음 출발 2분 전에 맞춰 정밀 스케줄링)
    _refreshTimer = Timer(const Duration(minutes: 2), _refresh);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        _manualOverride = true;
        _controller?.toggleScenario();
        _refresh();
      case 'refresh':
        _refresh();
      case 'settings':
        windowManager.show();
        windowManager.focus();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    _refreshTimer?.cancel();
    trayManager.removeListener(this);
    super.dispose();
  }
}
