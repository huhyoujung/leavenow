// 경기버스 도착정보 조회 (m.gbis.go.kr 비공개 API, 키 불필요)
// 엔드포인트: https://m.gbis.go.kr/api/stationArrivals?stationId=<id>
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/departure.dart';

class GbusBusService {
  static const _baseUrl = 'https://m.gbis.go.kr/api/stationArrivals';
  static const _searchUrl = 'https://m.gbis.go.kr/api/stationSearch';

  final Dio dio;

  GbusBusService({required this.dio});

  /// stationId(경기버스 정류장 ID)로 실시간 버스 도착정보를 조회한다.
  Future<List<Departure>> fetchArrivals(String stationId) async {
    try {
      print('[LEAVENOW] gbus fetchArrivals stationId=$stationId');
      final response = await dio.get(
        _baseUrl,
        queryParameters: {'stationId': stationId},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://m.gbis.go.kr/',
          },
        ),
      );
      print('[LEAVENOW] gbus response status=${response.statusCode}');

      var data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! Map) {
        print('[LEAVENOW] gbus unexpected data type: ${data.runtimeType}');
        return [];
      }

      final msgBody = data['response']?['msgBody'];
      if (msgBody is! Map) return [];

      final items = msgBody['busArrivalList'];
      if (items is! List) return [];

      final now = DateTime.now();
      final departures = <Departure>[];

      for (final item in items.whereType<Map>()) {
        final routeName = item['routeName']?.toString();
        if (routeName == null) continue;

        // predictTime1, predictTime2 는 분 단위
        for (final key in ['predictTime1', 'predictTime2']) {
          final minutes = item[key];
          if (minutes == null) continue;
          final mins = int.tryParse(minutes.toString());
          if (mins == null || mins < 0) continue;

          // drvEnd='Y'면 운행 종료
          if (item['drvEnd'] == 'Y') continue;

          departures.add(Departure(
            routeName: routeName,
            transportType: TransportType.bus,
            departureTime: now.add(Duration(minutes: mins)),
          ));
        }
      }

      departures.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      print('[LEAVENOW] gbus ${departures.length}개 도착정보 파싱됨');
      return departures;
    } catch (e, stack) {
      print('[LEAVENOW] gbus fetchArrivals ERROR: $e\n$stack');
      rethrow;
    }
  }

  /// stationId 정류장에 routes 노선이 있는지 검증한다.
  /// 반환값: null이면 정상, 문자열이면 경고 메시지.
  Future<String?> validateStation(
      String stationId, List<String> routes) async {
    try {
      final response = await dio.get(
        _baseUrl,
        queryParameters: {'stationId': stationId},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://m.gbis.go.kr/',
          },
        ),
      );
      var data = response.data;
      if (data is String) data = jsonDecode(data);
      if (data is! Map) {
        return '정류장 정보를 불러올 수 없습니다 (stationId: $stationId)';
      }

      final msgHeader = data['response']?['msgHeader'];
      final resultCode = msgHeader?['resultCode'];
      if (resultCode != 0) {
        return '정류장을 찾을 수 없습니다 (stationId: $stationId)';
      }

      final msgBody = data['response']?['msgBody'];
      final items = msgBody?['busArrivalList'];
      if (items is! List || items.isEmpty) {
        return '정류장을 찾을 수 없거나 현재 운행 중인 버스가 없습니다.\n(stationId: $stationId)';
      }

      if (routes.isNotEmpty) {
        final routeNames = items
            .whereType<Map>()
            .map((e) => e['routeName']?.toString() ?? '')
            .toList();
        final hasMatch = routeNames.any((name) =>
            routes.any((r) => name.toLowerCase().contains(r.toLowerCase())));
        if (!hasMatch) {
          final available = routeNames.take(5).join(', ');
          return '정류장(stationId: $stationId)에 해당 노선이 없습니다.\n'
              '입력한 노선: ${routes.join(', ')}\n'
              '이 정류장의 노선: $available${routeNames.length > 5 ? " 외 ${routeNames.length - 5}개" : ""}';
        }
      }

      return null;
    } catch (e) {
      return '정류장 확인 중 오류가 발생했습니다: $e';
    }
  }

  /// 키워드로 경기버스 정류장을 검색한다.
  /// 반환값: [{stationId, stationName, mobileNo, regionName}, ...]
  Future<List<Map<String, dynamic>>> searchStation(String keyword) async {
    try {
      final response = await dio.get(
        _searchUrl,
        queryParameters: {'keyword': keyword},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://m.gbis.go.kr/',
          },
        ),
      );
      var data = response.data;
      if (data is String) data = jsonDecode(data);
      if (data is! Map) return [];

      final records = data['records'];
      if (records is! List) return [];

      return records
          .whereType<Map>()
          .map((e) => {
                'stationId': e['stationId']?.toString() ?? '',
                'stationName': e['stationName']?.toString() ?? '',
                'mobileNo': e['mobileNo']?.toString() ?? '',
                'regionName': e['regionName']?.toString() ?? '',
              })
          .where((e) => e['stationId']!.isNotEmpty)
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      print('[LEAVENOW] gbus searchStation ERROR: $e');
      return [];
    }
  }
}
