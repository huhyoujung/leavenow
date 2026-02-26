// 하나의 대중교통 경로 (출발편 목록 포함)
import 'departure.dart';

class TransitRoute {
  final String id;
  final List<Departure> departures;

  const TransitRoute({
    required this.id,
    required this.departures,
  });

  List<Departure> upcomingDepartures(DateTime now, {int limit = 3}) {
    return departures
        .where((d) => d.minutesUntil(now) >= 0)
        .take(limit)
        .toList();
  }
}
