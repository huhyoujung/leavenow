// ODsay API로 두 좌표 사이의 대중교통 경로를 조회하는 서비스
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/transit_route.dart';
import '../models/departure.dart';
import 'naver_geocoding_service.dart';

/// 대중교통 경로 조회 관련 예외
class OdsayTransitException implements Exception {
  final String message;
  const OdsayTransitException(this.message);
  @override
  String toString() => 'OdsayTransitException: $message';
}

/// ODsay 대중교통 경로 탐색 서비스
///
/// ODsay API (searchPubTransPathT)를 통해
/// 두 좌표 사이의 대중교통 경로 목록을 조회한다.
///
/// 응답 구조:
/// {
///   "result": {
///     "path": [
///       {
///         "pathType": 1,
///         "info": { "totalTime": 45 },
///         "subPath": [
///           {
///             "trafficType": 2,       // 1=지하철, 2=버스, 3=도보(무시)
///             "sectionTime": 20,
///             "lane": [{ "busNo": "9401", "type": 11 }]
///           },
///           {
///             "trafficType": 1,
///             "sectionTime": 15,
///             "lane": [{ "subwayCode": 2, "subwayName": "2호선" }]
///           }
///         ]
///       }
///     ]
///   }
/// }
class OdsayTransitService {
  static const _baseUrl =
      'https://api.odsay.com/v1/api/searchPubTransPathT';

  final Dio dio;
  final String _apiKey;

  OdsayTransitService({
    required this.dio,
    required String apiKey,
  }) : _apiKey = apiKey;

  factory OdsayTransitService.fromEnv({required Dio dio}) {
    final key = dotenv.env['ODSAY_API_KEY'];
    if (key == null) {
      throw const OdsayTransitException(
          'ODSAY_API_KEY가 .env에 없습니다');
    }
    return OdsayTransitService(dio: dio, apiKey: key);
  }

  /// 두 좌표 사이의 대중교통 경로 목록을 조회한다.
  ///
  /// [origin] 출발지 좌표
  /// [destination] 목적지 좌표
  ///
  /// 각 경로에서 첫 번째 대중교통 subPath(도보 제외)로 [Departure]를 만든다.
  /// [departureTime]은 ODsay가 실시간 출발시간을 제공하지 않으므로 현재 시각 사용.
  ///
  /// API 오류 또는 네트워크 오류 시 [OdsayTransitException]을 throw한다.
  Future<List<TransitRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await dio.get(
        _baseUrl,
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

      // ODsay 에러 응답 확인 (result 없이 error 키가 있는 경우)
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
      if (paths is! List) {
        return [];
      }

      final now = DateTime.now();
      return paths
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map((entry) => _parsePath(entry.key, entry.value, now))
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

  /// 단일 path Map을 [TransitRoute]로 변환한다.
  ///
  /// subPath 중 trafficType이 1(지하철) 또는 2(버스)인 첫 번째 항목을
  /// 대표 교통수단으로 사용한다. trafficType 3(도보)은 무시한다.
  TransitRoute? _parsePath(int index, Map pathData, DateTime now) {
    final subPaths = pathData['subPath'];
    if (subPaths is! List || subPaths.isEmpty) return null;

    // 첫 번째 대중교통 subPath를 찾는다 (도보=3 제외)
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
      // 지하철: subwayName 사용
      routeName = firstLane['subwayName']?.toString() ?? '알 수 없음';
      transportType = TransportType.subway;
    } else {
      // 버스: busNo 사용
      routeName = firstLane['busNo']?.toString() ?? '알 수 없음';
      transportType = TransportType.bus;
    }

    // ODsay는 실시간 출발시간을 제공하지 않으므로 현재 시각을 departureTime으로 사용
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

  /// 대중교통 subPath 타입인지 확인한다.
  ///
  /// ODsay trafficType: 1=지하철, 2=버스, 3=도보(무시)
  bool _isTransitSubPath(dynamic trafficType) {
    return trafficType == 1 || trafficType == 2;
  }
}
