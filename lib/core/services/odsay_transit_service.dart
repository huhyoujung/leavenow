// ODsay API로 대중교통 경로 조회 + 실시간 도착정보 조회
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/transit_route.dart';
import '../models/departure.dart';
import 'naver_geocoding_service.dart';

class OdsayTransitException implements Exception {
  final String message;
  const OdsayTransitException(this.message);
  @override
  String toString() => 'OdsayTransitException: $message';
}

class OdsayTransitService {
  static const _routeUrl =
      'https://api.odsay.com/v1/api/searchPubTransPathT';
  static const _realtimeUrl =
      'https://api.odsay.com/v1/api/realtimeStation';

  final Dio dio;
  final String _apiKey;

  OdsayTransitService({
    required this.dio,
    required String apiKey,
  }) : _apiKey = apiKey;

  factory OdsayTransitService.fromEnv({required Dio dio}) {
    final key = dotenv.env['ODSAY_API_KEY'];
    if (key == null) {
      throw const OdsayTransitException('ODSAY_API_KEY가 .env에 없습니다');
    }
    return OdsayTransitService(dio: dio, apiKey: key);
  }

  /// 두 좌표 사이의 대중교통 경로 목록을 조회한다.
  Future<List<TransitRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await dio.get(
        _routeUrl,
        queryParameters: {
          'SX': origin.longitude,
          'SY': origin.latitude,
          'EX': destination.longitude,
          'EY': destination.latitude,
          'apiKey': _apiKey,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const OdsayTransitException('응답 형식이 올바르지 않습니다');
      }

      if (!data.containsKey('result')) {
        final errors = data['error'];
        if (errors is List && errors.isNotEmpty) {
          final firstError = errors.first;
          final message = firstError is Map
              ? (firstError['message'] ?? '알 수 없는 오류')
              : '알 수 없는 오류';
          throw OdsayTransitException('API 오류: $message');
        }
        throw const OdsayTransitException('응답에 result 필드가 없습니다');
      }

      final result = data['result'];
      if (result is! Map) {
        throw const OdsayTransitException('result 형식이 올바르지 않습니다');
      }

      final paths = result['path'];
      if (paths is! List) return [];

      return paths
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map((entry) => _parsePath(entry.key, entry.value))
          .where((route) => route != null)
          .cast<TransitRoute>()
          .toList();
    } on OdsayTransitException {
      rethrow;
    } on DioException catch (e) {
      throw OdsayTransitException('네트워크 오류: ${e.message}');
    } catch (e) {
      throw OdsayTransitException('경로 파싱 오류: $e');
    }
  }

  /// 정류장의 실시간 버스 도착정보를 조회한다.
  Future<List<Departure>> fetchRealtimeArrivals(int stationId) async {
    try {
      final response = await dio.get(
        _realtimeUrl,
        queryParameters: {
          'stationID': stationId,
          'apiKey': _apiKey,
        },
      );

      final data = response.data;
      if (data is! Map) return [];

      final result = data['result'];
      if (result is! Map) return [];

      final busList = result['real'];
      if (busList is! List) return [];

      final now = DateTime.now();
      final departures = <Departure>[];
      for (final bus in busList.whereType<Map>()) {
        departures.addAll(_parseRealtimeBus(bus, now));
      }
      departures.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      return departures;
    } catch (_) {
      return [];
    }
  }

  /// ODsay realtimeStation 응답의 버스 1건을 파싱한다.
  /// arrival1(첫 번째 버스), arrival2(두 번째 버스) 각각 Departure로 변환.
  List<Departure> _parseRealtimeBus(Map bus, DateTime now) {
    final routeName = bus['routeNm']?.toString();
    if (routeName == null) return [];

    final results = <Departure>[];
    for (final key in ['arrival1', 'arrival2']) {
      final arrival = bus[key];
      if (arrival is! Map) continue;
      final sec = arrival['arrivalSec'];
      if (sec is! int) continue;

      results.add(Departure(
        routeName: routeName,
        transportType: TransportType.bus,
        departureTime: now.add(Duration(seconds: sec)),
      ));
    }
    return results;
  }

  TransitRoute? _parsePath(int index, Map pathData) {
    final subPaths = pathData['subPath'];
    if (subPaths is! List || subPaths.isEmpty) return null;

    final transitSubPath = subPaths.whereType<Map>().firstWhere(
          (sp) => _isTransitSubPath(sp['trafficType']),
          orElse: () => {},
        );

    if (transitSubPath.isEmpty) return null;

    final trafficType = transitSubPath['trafficType'];
    final lane = transitSubPath['lane'];
    if (lane is! List || lane.isEmpty) return null;

    final firstLane = lane.first;
    if (firstLane is! Map) return null;

    final String routeName;
    final TransportType transportType;

    if (trafficType == 1) {
      routeName = firstLane['subwayName']?.toString() ?? '알 수 없음';
      transportType = TransportType.subway;
    } else {
      routeName = firstLane['busNo']?.toString() ?? '알 수 없음';
      transportType = TransportType.bus;
    }

    // 탑승 정류장 정보 추출
    final stationId = transitSubPath['startID'];
    final stationName = transitSubPath['startName']?.toString();

    return TransitRoute(
      id: 'route_$index',
      stationId: stationId is int ? stationId : int.tryParse('$stationId'),
      stationName: stationName,
      routeName: routeName,
      transportType: transportType,
    );
  }

  bool _isTransitSubPath(dynamic trafficType) {
    return trafficType == 1 || trafficType == 2;
  }
}
