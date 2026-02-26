// 앱 전체 상태 관리 - 시나리오, 경로 목록, 대표 루트
import 'models/transit_route.dart';
import 'services/naver_geocoding_service.dart';
import 'services/odsay_transit_service.dart';
import 'services/scenario_service.dart';

class AppController {
  final OdsayTransitService transitService;
  final NaverGeocodingService geocodingService;

  Scenario scenario;
  final String homeAddress;
  final String workAddress;
  String? preferredRouteId;

  List<TransitRoute> routes = [];

  AppController({
    required this.transitService,
    required this.geocodingService,
    required this.scenario,
    required this.homeAddress,
    required this.workAddress,
    required this.preferredRouteId,
  });

  TransitRoute? get preferredRoute {
    if (routes.isEmpty) return null;
    return routes.firstWhere(
      (r) => r.id == preferredRouteId,
      orElse: () => routes.first,
    );
  }

  Future<void> loadRoutes() async {
    final origin = scenario == Scenario.toWork ? homeAddress : workAddress;
    final destination = scenario == Scenario.toWork ? workAddress : homeAddress;

    final originCoord = await geocodingService.geocode(origin);
    final destCoord = await geocodingService.geocode(destination);

    if (originCoord == null || destCoord == null) return;

    routes = await transitService.fetchRoutes(
      origin: originCoord,
      destination: destCoord,
    );
  }

  void toggleScenario() {
    scenario = scenario == Scenario.toWork ? Scenario.toHome : Scenario.toWork;
  }
}
