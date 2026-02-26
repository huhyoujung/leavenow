// OdsayTransitService 단위 테스트 (Dio mock)
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/models/transit_route.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/odsay_transit_service.dart';

class MockDio extends Mock implements Dio {}

// ODsay 대중교통 경로 탐색 API 응답 구조:
// {
//   "result": {
//     "path": [
//       {
//         "pathType": 1,
//         "info": { "totalTime": 45 },
//         "subPath": [
//           {
//             "trafficType": 2,       // 1=지하철, 2=버스, 3=도보
//             "sectionTime": 20,
//             "lane": [{ "busNo": "9401", "type": 11 }]
//           },
//           {
//             "trafficType": 1,
//             "sectionTime": 15,
//             "lane": [{ "subwayCode": 2, "subwayName": "2호선" }]
//           }
//         ]
//       }
//     ]
//   }
// }

/// 버스 + 지하철 혼합 경로 mock 응답 (경로 2개)
Map<String, dynamic> _mockBusAndSubwayResponse() {
  return {
    'result': {
      'path': [
        {
          'pathType': 1,
          'info': {'totalTime': 65},
          'subPath': [
            {
              'trafficType': 3, // 도보 (무시)
              'sectionTime': 5,
            },
            {
              'trafficType': 2, // 버스
              'sectionTime': 20,
              'lane': [
                {'busNo': '9401', 'type': 11}
              ],
            },
            {
              'trafficType': 1, // 지하철
              'sectionTime': 15,
              'lane': [
                {'subwayCode': 2, 'subwayName': '2호선'}
              ],
            },
          ],
        },
        {
          'pathType': 1,
          'info': {'totalTime': 80},
          'subPath': [
            {
              'trafficType': 1, // 지하철
              'sectionTime': 30,
              'lane': [
                {'subwayCode': 9, 'subwayName': '신분당선'}
              ],
            },
          ],
        },
      ],
    },
  };
}

/// 지하철만 있는 경로 mock 응답
Map<String, dynamic> _mockSubwayOnlyResponse() {
  return {
    'result': {
      'path': [
        {
          'pathType': 1,
          'info': {'totalTime': 40},
          'subPath': [
            {
              'trafficType': 3, // 도보 (무시)
              'sectionTime': 5,
            },
            {
              'trafficType': 1, // 지하철
              'sectionTime': 35,
              'lane': [
                {'subwayCode': 9, 'subwayName': '신분당선'}
              ],
            },
          ],
        },
      ],
    },
  };
}

/// 빈 경로 mock 응답
Map<String, dynamic> _mockEmptyPathResponse() {
  return {
    'result': {
      'path': [],
    },
  };
}

/// ODsay 에러 응답 (result 없음)
Map<String, dynamic> _mockErrorResponse() {
  return {
    'error': [
      {'code': '500', 'message': '[ApiKeyAuthFailed] ApiKey authentication failed.'}
    ],
  };
}

void main() {
  late MockDio mockDio;
  late OdsayTransitService service;

  setUp(() {
    mockDio = MockDio();
    service = OdsayTransitService(
      dio: mockDio,
      apiKey: 'test-api-key',
    );
  });

  const origin = LatLng(latitude: 37.3595316, longitude: 127.1086228);
  const destination = LatLng(latitude: 37.4979502, longitude: 127.0276368);

  group('fetchRoutes', () {
    test('정상 응답 시 TransitRoute 목록 반환', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockBusAndSubwayResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      expect(routes, isNotEmpty);
      expect(routes.length, 2);
    });

    test('버스 subPath 첫 번째 대중교통 → TransportType.bus, busNo 파싱', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockBusAndSubwayResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      // 첫 번째 경로: 도보 이후 버스가 첫 대중교통
      final firstDeparture = routes.first.departures.first;
      expect(firstDeparture.transportType, TransportType.bus);
      expect(firstDeparture.routeName, '9401');
    });

    test('지하철 subPath 첫 번째 대중교통 → TransportType.subway, subwayName 파싱', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockSubwayOnlyResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      final firstDeparture = routes.first.departures.first;
      expect(firstDeparture.transportType, TransportType.subway);
      expect(firstDeparture.routeName, '신분당선');
    });

    test('departureTime이 현재 시각 이후이거나 같음', () async {
      final beforeCall = DateTime.now();

      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockBusAndSubwayResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      for (final route in routes) {
        for (final departure in route.departures) {
          expect(
            departure.departureTime.isAfter(beforeCall) ||
                departure.departureTime.isAtSameMomentAs(beforeCall),
            isTrue,
          );
        }
      }
    });

    test('빈 경로 목록 시 빈 리스트 반환', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockEmptyPathResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      expect(routes, isEmpty);
    });

    test('result 없는 에러 응답 시 OdsayTransitException 발생', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockErrorResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      expect(
        () => service.fetchRoutes(origin: origin, destination: destination),
        throwsA(isA<OdsayTransitException>()),
      );
    });

    test('네트워크 오류 시 OdsayTransitException 발생', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            message: 'Connection refused',
          ));

      expect(
        () => service.fetchRoutes(origin: origin, destination: destination),
        throwsA(isA<OdsayTransitException>()),
      );
    });

    test('두 번째 경로: 지하철이 첫 대중교통으로 올바르게 파싱됨', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: _mockBusAndSubwayResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      // 두 번째 경로: 첫 subPath가 지하철
      final secondDeparture = routes[1].departures.first;
      expect(secondDeparture.transportType, TransportType.subway);
      expect(secondDeparture.routeName, '신분당선');
    });
  });
}
