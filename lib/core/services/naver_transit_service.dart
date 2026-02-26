// 네이버 지도 API로 두 좌표 사이의 대중교통 경로를 조회하는 서비스
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/transit_route.dart';
import '../models/departure.dart';
import 'naver_geocoding_service.dart';

/// 대중교통 경로 조회 관련 예외
class TransitException implements Exception {
  final String message;
  const TransitException(this.message);
  @override
  String toString() => 'TransitException: $message';
}

/// 네이버 대중교통 경로 탐색 서비스
///
/// 네이버 지도 API (map-direction/v1/transit)를 통해
/// 두 좌표 사이의 대중교통 경로 목록을 조회한다.
///
/// 응답 구조:
/// {
///   "code": 0,
///   "message": "OK",
///   "currentDateTime": "2026-02-26T22:15:00",
///   "route": {
///     "traoptimal": [
///       {
///         "summary": { "duration": 3900000 },  // 밀리초
///         "legs": [
///           { "routeName": "9401", "type": 11, "duration": 1800000 }
///           // type: 11=간선버스, 12=지선버스, 21=지하철
///         ]
///       }
///     ]
///   }
/// }
class NaverTransitService {
  static const _baseUrl =
      'https://maps.apigw.ntruss.com/map-direction/v1/transit';

  final Dio dio;
  final String _clientId;
  final String _clientSecret;

  NaverTransitService({
    required this.dio,
    String? clientId,
    String? clientSecret,
  })  : _clientId = clientId ?? '',
        _clientSecret = clientSecret ?? '';

  factory NaverTransitService.fromEnv({required Dio dio}) {
    final id = dotenv.env['NAVER_CLIENT_ID'];
    final secret = dotenv.env['NAVER_CLIENT_SECRET'];
    if (id == null || secret == null) {
      throw TransitException(
          'NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 .env에 없습니다');
    }
    return NaverTransitService(dio: dio, clientId: id, clientSecret: secret);
  }

  /// 두 좌표 사이의 대중교통 경로 목록을 조회한다.
  ///
  /// [origin] 출발지 좌표
  /// [destination] 목적지 좌표
  ///
  /// 각 경로는 대표 교통수단(버스 또는 지하철)의 [Departure]를 포함하며,
  /// [departureTime]은 현재 시각 기준으로 계산된다.
  ///
  /// API 오류 또는 네트워크 오류 시 [TransitException]을 throw한다.
  Future<List<TransitRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await dio.get(
        _baseUrl,
        queryParameters: {
          'start': '${origin.longitude},${origin.latitude}',
          'goal': '${destination.longitude},${destination.latitude}',
          'lang': 'ko',
        },
        options: Options(headers: {
          'X-NCP-APIGW-API-KEY-ID': _clientId,
          'X-NCP-APIGW-API-KEY': _clientSecret,
        }),
      );

      final data = response.data;
      if (data is! Map) {
        throw const TransitException('응답 형식이 올바르지 않습니다');
      }

      // API 에러 코드 확인
      final code = data['code'];
      if (code != null && code != 0) {
        final message = data['message'] ?? '알 수 없는 오류';
        throw TransitException('API 오류 (code $code): $message');
      }

      final routeMap = data['route'];
      if (routeMap is! Map) {
        throw const TransitException('응답에 route 필드가 없습니다');
      }

      final traoptimal = routeMap['traoptimal'];
      if (traoptimal is! List) {
        return [];
      }

      final now = DateTime.now();
      return traoptimal
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map((entry) => _parseRoute(entry.key, entry.value, now))
          .where((route) => route != null)
          .cast<TransitRoute>()
          .toList();
    } on TransitException {
      rethrow;
    } on DioException catch (e) {
      throw TransitException('네트워크 오류: ${e.message}');
    } catch (e) {
      throw TransitException('경로 파싱 오류: $e');
    }
  }

  /// 단일 경로 Map을 [TransitRoute]로 변환한다.
  ///
  /// 경로에서 첫 번째 대중교통 leg(버스 또는 지하철)를 찾아 [Departure]로 만든다.
  /// summary.duration(밀리초)을 이용해 departureTime을 현재 시각으로 설정한다.
  /// (네이버 transit API는 실시간 출발 시간을 제공하지 않으므로 현재 시각 사용)
  TransitRoute? _parseRoute(int index, Map routeData, DateTime now) {
    final legs = routeData['legs'];
    if (legs is! List || legs.isEmpty) return null;

    // 첫 번째 대중교통 leg를 찾는다 (도보 제외)
    final transitLeg = legs.whereType<Map>().firstWhere(
          (leg) => _isTransitLeg(leg['type']),
          orElse: () => {},
        );

    if (transitLeg.isEmpty) return null;

    final routeName = transitLeg['routeName']?.toString() ?? '알 수 없음';
    final type = transitLeg['type'];
    final transportType = _parseTransportType(type);

    // 현재 시각을 departureTime으로 사용
    // summary.duration은 총 소요시간(밀리초)이므로 도착 예정 시간 계산에 활용 가능
    final departure = Departure(
      routeName: routeName,
      transportType: transportType,
      departureTime: now,
    );

    return TransitRoute(
      id: 'route_$index',
      departures: [departure],
    );
  }

  /// 대중교통 leg 타입인지 확인한다.
  ///
  /// 네이버 API leg type:
  /// 1 = 도보, 11 = 간선버스, 12 = 지선버스, 13 = 순환버스, 14 = 광역버스,
  /// 21 = 지하철, 22 = 기차, 100 = 택시 등
  bool _isTransitLeg(dynamic type) {
    if (type is! int) return false;
    // 10~29: 버스 및 지하철 계열
    return type >= 11 && type <= 29;
  }

  /// leg type을 [TransportType]으로 변환한다.
  TransportType _parseTransportType(dynamic type) {
    if (type is int && type >= 21 && type <= 29) {
      return TransportType.subway;
    }
    return TransportType.bus;
  }
}
