// NaverTransitService 단위 테스트 (Dio mock)
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/models/transit_route.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/naver_transit_service.dart';

class MockDio extends Mock implements Dio {}

// 실제 네이버 대중교통 API 응답 구조를 기반으로 한 mock 데이터
// 응답 형식:
// {
//   "code": 0,
//   "message": "OK",
//   "currentDateTime": "2026-02-26T22:15:00",
//   "route": {
//     "traoptimal": [
//       {
//         "summary": {
//           "duration": 3600000,    // 총 소요시간 (밀리초)
//           "departureTime": "2026-02-26T22:15:00",
//           "waypoints": []
//         },
//         "legs": [
//           {
//             "routeColor": "0000FF",
//             "routeName": "9401",
//             "type": 11,   // 11=간선버스, 12=지선버스, 21=지하철
//             "duration": 3600000
//           }
//         ]
//       }
//     ]
//   }
// }

/// 네이버 transit API mock 응답: 버스 + 지하철 2가지 경로
Map<String, dynamic> _mockTransitResponse({
  String currentDateTime = '2026-02-26T22:15:00',
}) {
  return {
    'code': 0,
    'message': 'OK',
    'currentDateTime': currentDateTime,
    'route': {
      'traoptimal': [
        {
          'summary': {
            'duration': 3900000, // 65분 (밀리초)
          },
          'legs': [
            {
              'routeName': '9401',
              'type': 11, // 간선버스
              'duration': 1800000,
            },
            {
              'routeName': '2호선',
              'type': 21, // 지하철
              'duration': 1200000,
            },
          ],
        },
        {
          'summary': {
            'duration': 4800000, // 80분 (밀리초)
          },
          'legs': [
            {
              'routeName': '광역급행',
              'type': 11, // 간선버스
              'duration': 2400000,
            },
          ],
        },
      ],
    },
  };
}

/// 빈 경로 목록 mock 응답
Map<String, dynamic> _mockEmptyRoutesResponse() {
  return {
    'code': 0,
    'message': 'OK',
    'currentDateTime': '2026-02-26T22:15:00',
    'route': {
      'traoptimal': [],
    },
  };
}

/// 에러 mock 응답
Map<String, dynamic> _mockErrorResponse() {
  return {
    'code': 1,
    'message': 'Invalid Coordinate',
  };
}

void main() {
  late MockDio mockDio;
  late NaverTransitService service;

  setUp(() {
    mockDio = MockDio();
    service = NaverTransitService(
      dio: mockDio,
      clientId: 'test-id',
      clientSecret: 'test-secret',
    );
  });

  const origin = LatLng(latitude: 37.3595316, longitude: 127.1086228);
  const destination = LatLng(latitude: 37.4979502, longitude: 127.0276368);

  group('fetchRoutes', () {
    test('정상 응답 시 TransitRoute 목록 반환', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: _mockTransitResponse(),
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

    test('각 경로에 Departure 정보가 올바르게 파싱됨', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: _mockTransitResponse(
              currentDateTime: '2026-02-26T08:00:00',
            ),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      final firstRoute = routes.first;
      expect(firstRoute.departures, isNotEmpty);

      final firstDeparture = firstRoute.departures.first;
      // 첫 번째 경로의 첫 번째 leg가 버스(type 11)이므로 TransportType.bus
      expect(firstDeparture.transportType, TransportType.bus);
      expect(firstDeparture.routeName, '9401');
    });

    test('departureTime이 현재 시각 이후로 설정됨', () async {
      final beforeCall = DateTime.now();

      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: _mockTransitResponse(),
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
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: _mockEmptyRoutesResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      expect(routes, isEmpty);
    });

    test('API 에러 코드 응답 시 TransitException 발생', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: _mockErrorResponse(),
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      expect(
        () => service.fetchRoutes(origin: origin, destination: destination),
        throwsA(isA<TransitException>()),
      );
    });

    test('네트워크 오류 시 TransitException 발생', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            message: 'Connection refused',
          ));

      expect(
        () => service.fetchRoutes(origin: origin, destination: destination),
        throwsA(isA<TransitException>()),
      );
    });

    test('지하철 leg는 TransportType.subway로 파싱됨', () async {
      // 지하철만 있는 경로 mock
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: {
              'code': 0,
              'message': 'OK',
              'currentDateTime': '2026-02-26T08:00:00',
              'route': {
                'traoptimal': [
                  {
                    'summary': {'duration': 2400000},
                    'legs': [
                      {
                        'routeName': '신분당선',
                        'type': 21, // 지하철
                        'duration': 1800000,
                      },
                    ],
                  },
                ],
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));

      final routes = await service.fetchRoutes(
        origin: origin,
        destination: destination,
      );

      expect(routes.first.departures.first.transportType, TransportType.subway);
      expect(routes.first.departures.first.routeName, '신분당선');
    });
  });
}
