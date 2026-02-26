// Departure 모델 단위 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/models/departure.dart';

void main() {
  group('Departure', () {
    test('남은 분 계산', () {
      final now = DateTime(2026, 2, 26, 8, 30);
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.minutesUntil(now), 12);
    });

    test('출발했으면 음수 반환', () {
      final now = DateTime(2026, 2, 26, 8, 50);
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.minutesUntil(now), -8);
    });

    test('displayLabel: 버스는 노선 번호 표시', () {
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.displayLabel, '🚌 9401');
    });

    test('displayLabel: 지하철은 호선 표시', () {
      final departure = Departure(
        routeName: '2호선',
        transportType: TransportType.subway,
        departureTime: DateTime(2026, 2, 26, 8, 49),
      );

      expect(departure.displayLabel, '🚇 2호선');
    });
  });
}
