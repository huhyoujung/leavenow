// 하나의 대중교통 경로 (탑승 정류장 + 실시간 출발편 목록)
import 'departure.dart';

class TransitRoute {
  final String id;
  final int? stationId;
  final String? stationName;
  final String? routeName;
  final TransportType? transportType;
  List<Departure> departures;

  TransitRoute({
    required this.id,
    this.stationId,
    this.stationName,
    this.routeName,
    this.transportType,
    this.departures = const [],
  });

  List<Departure> upcomingDepartures(DateTime now, {int limit = 3}) {
    return departures
        .where((d) => d.minutesUntil(now) >= 0)
        .take(limit)
        .toList();
  }
}
