// AppController 단위 테스트 - 서비스 통합 및 상태 관리
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/app_controller.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/models/transit_route.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/odsay_transit_service.dart';
import 'package:leavenow/core/services/scenario_service.dart';

class MockNaverGeocodingService extends Mock implements NaverGeocodingService {}
class MockOdsayTransitService extends Mock implements OdsayTransitService {}

void main() {
  late MockNaverGeocodingService mockGeocode;
  late MockOdsayTransitService mockTransit;

  setUp(() {
    mockGeocode = MockNaverGeocodingService();
    mockTransit = MockOdsayTransitService();
    registerFallbackValue(const LatLng(latitude: 0, longitude: 0));
  });

  AppController makeController({String? preferredRouteId}) => AppController(
    transitService: mockTransit,
    geocodingService: mockGeocode,
    scenario: Scenario.toWork,
    homeAddress: '판교',
    workAddress: '강남',
    preferredRouteId: preferredRouteId,
  );

  test('경로 로드 후 routes가 채워짐', () async {
    when(() => mockGeocode.geocode(any()))
        .thenAnswer((_) async => const LatLng(latitude: 37.394, longitude: 127.111));
    when(() => mockTransit.fetchRoutes(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
        )).thenAnswer((_) async => [
          TransitRoute(
            id: 'route-0',
            departures: [
              Departure(
                routeName: '9401',
                transportType: TransportType.bus,
                departureTime: DateTime.now().add(const Duration(minutes: 10)),
              ),
            ],
          ),
        ]);

    final controller = makeController();
    await controller.loadRoutes();

    expect(controller.routes.isNotEmpty, true);
  });

  test('preferredRoute: preferredRouteId 없으면 첫 번째 경로 반환', () async {
    when(() => mockGeocode.geocode(any()))
        .thenAnswer((_) async => const LatLng(latitude: 37.394, longitude: 127.111));
    when(() => mockTransit.fetchRoutes(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
        )).thenAnswer((_) async => [
          TransitRoute(id: 'route-0', departures: []),
          TransitRoute(id: 'route-1', departures: []),
        ]);

    final controller = makeController();
    await controller.loadRoutes();

    expect(controller.preferredRoute?.id, 'route-0');
  });

  test('preferredRoute: preferredRouteId 있으면 해당 경로 반환', () async {
    when(() => mockGeocode.geocode(any()))
        .thenAnswer((_) async => const LatLng(latitude: 37.394, longitude: 127.111));
    when(() => mockTransit.fetchRoutes(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
        )).thenAnswer((_) async => [
          TransitRoute(id: 'route-0', departures: []),
          TransitRoute(id: 'route-1', departures: []),
        ]);

    final controller = makeController(preferredRouteId: 'route-1');
    await controller.loadRoutes();

    expect(controller.preferredRoute?.id, 'route-1');
  });

  test('toggleScenario: toWork → toHome', () {
    final controller = makeController();
    expect(controller.scenario, Scenario.toWork);
    controller.toggleScenario();
    expect(controller.scenario, Scenario.toHome);
  });

  test('toggleScenario: toHome → toWork', () {
    final controller = AppController(
      transitService: mockTransit,
      geocodingService: mockGeocode,
      scenario: Scenario.toHome,
      homeAddress: '판교',
      workAddress: '강남',
      preferredRouteId: null,
    );
    controller.toggleScenario();
    expect(controller.scenario, Scenario.toWork);
  });

  test('geocoding 실패 시 routes 비어있음', () async {
    when(() => mockGeocode.geocode(any())).thenAnswer((_) async => null);

    final controller = makeController();
    await controller.loadRoutes();

    expect(controller.routes, isEmpty);
  });
}
