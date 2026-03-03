// 앱 전체 상태 관리 - 정류장별 실시간 버스 도착정보
import 'models/departure.dart';
import 'services/seoul_bus_service.dart';
import 'services/scenario_service.dart';

class AppController {
  final SeoulBusService busService;

  Scenario scenario;
  final String homeArsId;
  final String workArsId;
  final List<String> homeRoutes;
  final List<String> workRoutes;

  List<Departure> departures = [];

  AppController({
    required this.busService,
    required this.scenario,
    required this.homeArsId,
    required this.workArsId,
    this.homeRoutes = const [],
    this.workRoutes = const [],
  });

  String get currentArsId =>
      scenario == Scenario.toWork ? homeArsId : workArsId;

  List<String> get currentRoutes =>
      scenario == Scenario.toWork ? homeRoutes : workRoutes;

  /// 실시간 도착정보를 조회한다. 노선 필터가 설정돼 있으면 해당 노선만 반환.
  Future<void> refreshArrivals() async {
    final arsId = currentArsId;
    if (arsId.isEmpty) return;
    var all = await busService.fetchArrivals(arsId);
    final routes = currentRoutes;
    if (routes.isNotEmpty) {
      all = all
          .where((d) => routes.any(
              (r) => d.routeName.toLowerCase().contains(r.toLowerCase())))
          .toList();
    }
    departures = all;
  }

  void toggleScenario() {
    scenario = scenario == Scenario.toWork ? Scenario.toHome : Scenario.toWork;
  }
}
