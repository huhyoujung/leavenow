// ScenarioService 단위 테스트 - GPS/시간 기반 출퇴근 시나리오 판단
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/scenario_service.dart';

void main() {
  const home = LatLng(latitude: 37.394, longitude: 127.111); // 판교
  const work = LatLng(latitude: 37.498, longitude: 127.028); // 강남

  group('GPS 기반 감지', () {
    test('집 반경 500m → 출근 모드', () {
      // 집에서 약 300m 떨어진 위치
      const current = LatLng(latitude: 37.3967, longitude: 127.111);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, Scenario.toWork);
    });

    test('회사 반경 500m → 퇴근 모드', () {
      // 회사에서 약 200m 떨어진 위치
      const current = LatLng(latitude: 37.4997, longitude: 127.028);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, Scenario.toHome);
    });

    test('범위 밖 → null 반환', () {
      const current = LatLng(latitude: 37.55, longitude: 127.00);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, isNull);
    });

    test('정확히 집 위치 → 출근 모드', () {
      final scenario = ScenarioService.detectByLocation(
        current: home,
        home: home,
        work: work,
      );
      expect(scenario, Scenario.toWork);
    });
  });

  group('시간 기반 감지', () {
    test('오전 → 출근 모드', () {
      final time = DateTime(2026, 2, 26, 8, 30);
      expect(
        ScenarioService.detectByTime(time, thresholdHour: 15),
        Scenario.toWork,
      );
    });

    test('오후 3시 이후 → 퇴근 모드', () {
      final time = DateTime(2026, 2, 26, 17, 0);
      expect(
        ScenarioService.detectByTime(time, thresholdHour: 15),
        Scenario.toHome,
      );
    });

    test('정확히 기준 시각 → 퇴근 모드', () {
      final time = DateTime(2026, 2, 26, 15, 0);
      expect(
        ScenarioService.detectByTime(time, thresholdHour: 15),
        Scenario.toHome,
      );
    });

    test('기준 시각 커스텀 (14시) 적용', () {
      final time = DateTime(2026, 2, 26, 14, 30);
      expect(
        ScenarioService.detectByTime(time, thresholdHour: 14),
        Scenario.toHome,
      );
    });
  });
}
