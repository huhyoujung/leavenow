// 네이버 Geocoding API로 주소를 위경도 좌표로 변환
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});
}

class GeocodingException implements Exception {
  final String message;
  const GeocodingException(this.message);
  @override
  String toString() => 'GeocodingException: $message';
}

class NaverGeocodingService {
  static const _baseUrl =
      'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';

  final Dio dio;
  final String _clientId;
  final String _clientSecret;

  NaverGeocodingService({
    required this.dio,
    String? clientId,
    String? clientSecret,
  })  : _clientId = clientId ?? '',
        _clientSecret = clientSecret ?? '';

  factory NaverGeocodingService.fromEnv({required Dio dio}) {
    final id = dotenv.env['NAVER_CLIENT_ID'];
    final secret = dotenv.env['NAVER_CLIENT_SECRET'];
    if (id == null || secret == null) {
      throw GeocodingException('NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 .env에 없습니다');
    }
    return NaverGeocodingService(dio: dio, clientId: id, clientSecret: secret);
  }

  /// 주소를 위경도 좌표로 변환한다.
  /// 주소를 찾지 못하면 null을 반환한다.
  /// 네트워크/파싱 오류 시 [GeocodingException]을 throw한다.
  Future<LatLng?> geocode(String address) async {
    try {
      final response = await dio.get(
        _baseUrl,
        queryParameters: {'query': address},
        options: Options(headers: {
          'X-NCP-APIGW-API-KEY-ID': _clientId,
          'X-NCP-APIGW-API-KEY': _clientSecret,
        }),
      );

      final data = response.data;
      if (data is! Map || !data.containsKey('addresses')) {
        throw GeocodingException('응답 형식이 올바르지 않습니다: addresses 필드 없음');
      }

      final addresses = data['addresses'] as List;
      if (addresses.isEmpty) return null;

      final first = addresses.first as Map<String, dynamic>;
      final x = double.tryParse(first['x']?.toString() ?? '');
      final y = double.tryParse(first['y']?.toString() ?? '');

      if (x == null || y == null) {
        throw GeocodingException('좌표 파싱 실패: x=$x, y=$y');
      }

      return LatLng(latitude: y, longitude: x);
    } on DioException catch (e) {
      throw GeocodingException('네트워크 오류: ${e.message}');
    }
  }
}
