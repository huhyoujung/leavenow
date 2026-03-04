// AppController 단위 테스트 - 서울/경기버스 서비스 통합 및 상태 관리
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/app_controller.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/repositories/settings_repository.dart';
import 'package:leavenow/core/services/scenario_service.dart';
import 'package:leavenow/core/services/seoul_bus_service.dart';
import 'package:leavenow/core/services/gbus_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockSeoulBusService extends Mock implements SeoulBusService {
  @override
  final Dio dio = Dio();
}

class MockGbusBusService extends Mock implements GbusBusService {
  @override
  final Dio dio = Dio();
}

void main() {
  late MockSeoulBusService mockSeoul;
  late MockGbusBusService mockGbus;

  setUp(() {
    mockSeoul = MockSeoulBusService();
    mockGbus = MockGbusBusService();
  });

  AppController makeController({
    StationType homeType = StationType.seoul,
    StationType workType = StationType.seoul,
    Scenario scenario = Scenario.toWork,
    List<String> homeRoutes = const [],
    List<String> workRoutes = const [],
  }) =>
      AppController(
        seoulBusService: mockSeoul,
        gbusBusService: mockGbus,
        scenario: scenario,
        homeArsId: '14004',
        workArsId: '16248',
        homeRoutes: homeRoutes,
        workRoutes: workRoutes,
        homeStationType: homeType,
        workStationType: workType,
      );

  group('refreshArrivals - 서울 정류장', () {
    test('toWork 시나리오에서 서울 서비스 호출', () async {
      final departures = [
        Departure(
          routeName: '343',
          transportType: TransportType.bus,
          departureTime: DateTime.now().add(const Duration(minutes: 5)),
        ),
      ];
      when(() => mockSeoul.fetchArrivals(any()))
          .thenAnswer((_) async => departures);

      final ctrl = makeController(homeType: StationType.seoul);
      await ctrl.refreshArrivals();

      verify(() => mockSeoul.fetchArrivals('14004')).called(1);
      verifyNever(() => mockGbus.fetchArrivals(any()));
      expect(ctrl.departures.length, 1);
    });

    test('노선 필터 적용', () async {
      final departures = [
        Departure(
          routeName: '343',
          transportType: TransportType.bus,
          departureTime: DateTime.now().add(const Duration(minutes: 5)),
        ),
        Departure(
          routeName: '4412',
          transportType: TransportType.bus,
          departureTime: DateTime.now().add(const Duration(minutes: 10)),
        ),
      ];
      when(() => mockSeoul.fetchArrivals(any()))
          .thenAnswer((_) async => departures);

      final ctrl = makeController(
        homeType: StationType.seoul,
        homeRoutes: ['343'],
      );
      await ctrl.refreshArrivals();

      expect(ctrl.departures.length, 1);
      expect(ctrl.departures.first.routeName, '343');
    });
  });

  group('refreshArrivals - 경기 정류장', () {
    test('toWork 시나리오에서 경기 서비스 호출', () async {
      final departures = [
        Departure(
          routeName: '1150',
          transportType: TransportType.bus,
          departureTime: DateTime.now().add(const Duration(minutes: 22)),
        ),
      ];
      when(() => mockGbus.fetchArrivals(any()))
          .thenAnswer((_) async => departures);

      final ctrl = makeController(homeType: StationType.gyeonggi);
      await ctrl.refreshArrivals();

      verify(() => mockGbus.fetchArrivals('14004')).called(1);
      verifyNever(() => mockSeoul.fetchArrivals(any()));
      expect(ctrl.departures.length, 1);
    });

    test('toHome 시나리오에서 workStationType 사용', () async {
      when(() => mockGbus.fetchArrivals(any())).thenAnswer((_) async => []);
      when(() => mockSeoul.fetchArrivals(any())).thenAnswer((_) async => []);

      final ctrl = makeController(
        homeType: StationType.seoul,
        workType: StationType.gyeonggi,
        scenario: Scenario.toHome,
      );
      await ctrl.refreshArrivals();

      verify(() => mockGbus.fetchArrivals('16248')).called(1);
      verifyNever(() => mockSeoul.fetchArrivals(any()));
    });
  });

  group('toggleScenario', () {
    test('toWork → toHome 전환', () {
      final ctrl = makeController(scenario: Scenario.toWork);
      ctrl.toggleScenario();
      expect(ctrl.scenario, Scenario.toHome);
    });

    test('toHome → toWork 전환', () {
      final ctrl = makeController(scenario: Scenario.toHome);
      ctrl.toggleScenario();
      expect(ctrl.scenario, Scenario.toWork);
    });
  });
}
