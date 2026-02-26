// 하나의 출발 교통편 정보 (노선명, 수단, 출발 시각)
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

  int minutesUntil(DateTime now) {
    return departureTime.difference(now).inMinutes;
  }

  String get displayLabel {
    final icon = transportType == TransportType.bus ? '🚌' : '🚇';
    return '$icon $routeName';
  }
}
