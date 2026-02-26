// NaverGeocodingService 단위 테스트 (Dio mock)
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late NaverGeocodingService service;

  setUp(() {
    mockDio = MockDio();
    service = NaverGeocodingService(dio: mockDio);
  });

  test('주소를 좌표로 변환', () async {
    when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {
            'addresses': [
              {'x': '127.0276', 'y': '37.4979'}
            ]
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final result = await service.geocode('서울시 강남구 테헤란로 123');

    expect(result, isNotNull);
    expect(result!.longitude, 127.0276);
    expect(result.latitude, 37.4979);
  });

  test('결과 없으면 null 반환', () async {
    when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {'addresses': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final result = await service.geocode('존재하지않는주소abc');
    expect(result, isNull);
  });
}
