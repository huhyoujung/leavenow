// 하나의 출발 교통편 정보 (노선명, 수단, 도착 예정 시간)
enum TransportType { bus, subway }

class Departure {
  final String routeName;
  final TransportType transportType;
  final DateTime departureTime;

  const Departure({
    required this.routeName,
    required this.transportType,
    required this.departureTime,
  });

  /// 현재 시각(now)에서 출발까지 남은 분을 반환한다.
  int minutesUntil(DateTime now) {
    return departureTime.difference(now).inMinutes;
  }

  String get displayLabel {
    final icon = transportType == TransportType.bus ? '🚌' : '🚇';
    return '$icon $routeName';
  }
}
