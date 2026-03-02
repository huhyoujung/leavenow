// 서울시 버스도착정보 조회 (m.bus.go.kr, 키 불필요)
import 'package:dio/dio.dart';
import '../models/departure.dart';

class SeoulBusService {
  static const _baseUrl =
      'http://m.bus.go.kr/mBus/bus/getStationByUid.bms';

  final Dio dio;

  SeoulBusService({required this.dio});

  /// arsId(정류소 고유번호)로 실시간 버스 도착정보를 조회한다.
  Future<List<Departure>> fetchArrivals(String arsId) async {
    try {
      final response = await dio.get(
        _baseUrl,
        queryParameters: {'arsId': arsId},
      );

      final data = response.data;
      if (data is! Map) return [];

      final items = data['resultList'];
      if (items is! List) return [];

      final now = DateTime.now();
      final departures = <Departure>[];

      for (final item in items.whereType<Map>()) {
        final routeName = item['rtNm']?.toString();
        if (routeName == null) continue;

        for (final msgKey in ['arrmsg1', 'arrmsg2']) {
          final msg = item[msgKey]?.toString() ?? '';
          final seconds = _parseArrivalMsg(msg);
          if (seconds == null) continue;

          departures.add(Departure(
            routeName: routeName,
            transportType: TransportType.bus,
            departureTime: now.add(Duration(seconds: seconds)),
          ));
        }
      }

      departures.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      return departures;
    } catch (_) {
      return [];
    }
  }

  /// 도착 메시지를 초 단위로 파싱한다.
  /// "3분12초후[3번째 전]" → 192, "곧 도착" → 0, "운행종료" → null
  int? _parseArrivalMsg(String msg) {
    if (msg.contains('운행종료') || msg.contains('출발대기')) return null;
    if (msg.contains('곧 도착')) return 0;

    int totalSeconds = 0;
    bool found = false;

    final minMatch = RegExp(r'(\d+)분').firstMatch(msg);
    if (minMatch != null) {
      totalSeconds += int.parse(minMatch.group(1)!) * 60;
      found = true;
    }

    final secMatch = RegExp(r'(\d+)초').firstMatch(msg);
    if (secMatch != null) {
      totalSeconds += int.parse(secMatch.group(1)!);
      found = true;
    }

    return found ? totalSeconds : null;
  }
}
