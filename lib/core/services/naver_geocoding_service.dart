// 네이버 Geocoding API로 주소를 위경도 좌표로 변환
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});
}

class NaverGeocodingService {
  static const _baseUrl =
      'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';

  final Dio dio;
  final String? clientId;
  final String? clientSecret;

  NaverGeocodingService({
    required this.dio,
    String? clientId,
    String? clientSecret,
  })  : clientId = clientId,
        clientSecret = clientSecret;

  /// 프로덕션용 팩토리: dotenv에서 API 키를 읽어 생성
  factory NaverGeocodingService.fromEnv({required Dio dio}) {
    return NaverGeocodingService(
      dio: dio,
      clientId: dotenv.env['NAVER_CLIENT_ID'],
      clientSecret: dotenv.env['NAVER_CLIENT_SECRET'],
    );
  }

  Future<LatLng?> geocode(String address) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {'query': address},
      options: Options(headers: {
        'X-NCP-APIGW-API-KEY-ID': clientId ?? '',
        'X-NCP-APIGW-API-KEY': clientSecret ?? '',
      }),
    );

    final addresses = response.data['addresses'] as List;
    if (addresses.isEmpty) return null;

    final first = addresses.first as Map<String, dynamic>;
    return LatLng(
      latitude: double.parse(first['y'] as String),
      longitude: double.parse(first['x'] as String),
    );
  }
}
