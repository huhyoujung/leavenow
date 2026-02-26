// TransitRoute 모델 단위 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/models/transit_route.dart';

void main() {
  group('TransitRoute', () {
    test('다음 출발편 N개 반환', () {
      final now = DateTime(2026, 2, 26, 8, 30);
      final route = TransitRoute(
        id: 'route-1',
        departures: [
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 8, 42),
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 3),
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 24),
          ),
        ],
      );

      final upcoming = route.upcomingDepartures(now, limit: 2);
      expect(upcoming.length, 2);
      expect(upcoming.first.minutesUntil(now), 12);
    });

    test('이미 출발한 편은 제외', () {
      final now = DateTime(2026, 2, 26, 8, 50);
      final route = TransitRoute(
        id: 'route-1',
        departures: [
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 8, 42), // 이미 출발
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 3),
          ),
        ],
      );

      final upcoming = route.upcomingDepartures(now);
      expect(upcoming.length, 1);
      expect(upcoming.first.minutesUntil(now), 13);
    });
  });
}
