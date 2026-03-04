// 출근/퇴근 시나리오 판단: GPS → 시간 → 수동 우선순위
import 'dart:math';

enum Scenario { toWork, toHome }

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng({required this.latitude, required this.longitude});
}

class ScenarioService {
  static const _radiusMeters = 500.0;

  /// GPS 위치로 시나리오 판단. 집/회사 반경 500m 밖이면 null 반환.
  static Scenario? detectByLocation({
    required LatLng current,
    required LatLng home,
    required LatLng work,
  }) {
    if (_distanceMeters(current, home) <= _radiusMeters) return Scenario.toWork;
    if (_distanceMeters(current, work) <= _radiusMeters) return Scenario.toHome;
    return null;
  }

  /// 시간으로 시나리오 판단.
  /// 오전 3시 ~ thresholdHour 사이면 출근, 그 외(새벽/저녁)면 퇴근.
  static Scenario detectByTime(DateTime time, {required int thresholdHour}) {
    final h = time.hour;
    return (h >= 3 && h < thresholdHour) ? Scenario.toWork : Scenario.toHome;
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final c = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLon * sinDLon;
    return earthRadius * 2 * atan2(sqrt(c), sqrt(1 - c));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
