// 앱 전체 상태 관리 - 정류장별 실시간 버스 도착정보
import 'models/departure.dart';
import 'services/seoul_bus_service.dart';
import 'services/scenario_service.dart';

class AppController {
  final SeoulBusService busService;

  Scenario scenario;
  final String homeArsId;
  final String workArsId;

  List<Departure> departures = [];

  AppController({
    required this.busService,
    required this.scenario,
    required this.homeArsId,
    required this.workArsId,
  });

  String get currentArsId =>
      scenario == Scenario.toWork ? homeArsId : workArsId;

  /// 실시간 도착정보를 조회한다.
  Future<void> refreshArrivals() async {
    final arsId = currentArsId;
    if (arsId.isEmpty) return;
    departures = await busService.fetchArrivals(arsId);
  }

  void toggleScenario() {
    scenario = scenario == Scenario.toWork ? Scenario.toHome : Scenario.toWork;
  }
}
