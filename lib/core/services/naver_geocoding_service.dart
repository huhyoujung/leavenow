// 네이버 Geocoding API + Local Search API로 주소/장소명 검색 및 좌표 변환
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
  static const _geocodeUrl =
      'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';
  static const _localSearchUrl =
      'https://openapi.naver.com/v1/search/local.json';

  final Dio dio;
  final String _clientId;
  final String _clientSecret;
  // 건물명/장소명 검색용 (developers.naver.com 별도 발급, 선택)
  final String? _searchClientId;
  final String? _searchClientSecret;

  NaverGeocodingService({
    required this.dio,
    String? clientId,
    String? clientSecret,
    String? searchClientId,
    String? searchClientSecret,
  })  : _clientId = clientId ?? '',
        _clientSecret = clientSecret ?? '',
        _searchClientId = searchClientId,
        _searchClientSecret = searchClientSecret;

  factory NaverGeocodingService.fromEnv({required Dio dio}) {
    final id = dotenv.env['NAVER_CLIENT_ID'];
    final secret = dotenv.env['NAVER_CLIENT_SECRET'];
    if (id == null || secret == null) {
      throw GeocodingException('NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 .env에 없습니다');
    }
    return NaverGeocodingService(
      dio: dio,
      clientId: id,
      clientSecret: secret,
      searchClientId: dotenv.env['NAVER_SEARCH_CLIENT_ID'],
      searchClientSecret: dotenv.env['NAVER_SEARCH_CLIENT_SECRET'],
    );
  }

  /// Geocoding API로 도로명/지번 주소 검색
  Future<List<String>> _searchByGeocode(String query) async {
    try {
      final response = await dio.get(
        _geocodeUrl,
        queryParameters: {'query': query, 'count': '5'},
        options: Options(headers: {
          'X-NCP-APIGW-API-KEY-ID': _clientId,
          'X-NCP-APIGW-API-KEY': _clientSecret,
        }),
      );
      final data = response.data;
      if (data is! Map || !data.containsKey('addresses')) return [];
      final addresses = data['addresses'] as List;
      return addresses
          .map((a) {
            final m = a as Map<String, dynamic>;
            return (m['roadAddress'] as String?)?.trim() ??
                (m['jibunAddress'] as String?)?.trim() ??
                '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, String> get _localSearchHeaders => {
        'X-Naver-Client-Id': _searchClientId ?? '',
        'X-Naver-Client-Secret': _searchClientSecret ?? '',
        // 웹 환경으로 등록된 경우 Referer 필요
        'Referer': 'https://localhost',
      };

  /// Local Search API로 장소명 자동완성 (NAVER_SEARCH_CLIENT_ID 필요)
  /// 주소가 아닌 장소명(역명, 건물명)을 반환한다.
  Future<List<String>> _searchByLocal(String query) async {
    if (_searchClientId == null || _searchClientSecret == null) return [];
    try {
      final response = await dio.get(
        _localSearchUrl,
        queryParameters: {'query': query, 'display': '5'},
        options: Options(headers: _localSearchHeaders),
      );
      final data = response.data;
      if (data is! Map || !data.containsKey('items')) return [];
      final items = data['items'] as List;
      return items
          .map((item) {
            final m = item as Map<String, dynamic>;
            // 장소명 추출 (HTML 태그 제거, 예: <b>염창역</b> → 염창역)
            return (m['title'] as String?)
                    ?.replaceAll(RegExp(r'<[^>]*>'), '')
                    .trim() ??
                '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[LeaveNow] LocalSearch error: $e');
      return [];
    }
  }

  /// 장소명으로 Local Search에서 도로명주소를 조회한다 (geocode 폴백용).
  /// "염창역" → "서울특별시 강서구 강서로 지하 217"
  Future<String?> resolveAddressViaLocalSearch(String placeName) async {
    if (_searchClientId == null || _searchClientSecret == null) return null;
    try {
      final response = await dio.get(
        _localSearchUrl,
        queryParameters: {'query': placeName, 'display': '1'},
        options: Options(headers: _localSearchHeaders),
      );
      final data = response.data;
      if (data is! Map || !data.containsKey('items')) return null;
      final items = data['items'] as List;
      if (items.isEmpty) return null;
      final first = items.first as Map<String, dynamic>;
      final road = (first['roadAddress'] as String?)?.trim();
      final addr = (first['address'] as String?)?.trim();
      return (road?.isNotEmpty == true) ? road : addr;
    } catch (_) {
      return null;
    }
  }

  /// 주소/장소명 자동완성 목록 반환 (최대 5개).
  /// Geocoding + Local Search 병렬 호출 후 중복 제거하여 합산.
  Future<List<String>> searchAddresses(String query) async {
    if (query.trim().length < 2) return [];

    final results = await Future.wait([
      _searchByGeocode(query),
      _searchByLocal(query),
    ]);

    final seen = <String>{};
    final merged = <String>[];
    for (final list in results) {
      for (final addr in list) {
        if (seen.add(addr)) merged.add(addr);
      }
    }
    return merged.take(5).toList();
  }

  /// 주소를 위경도 좌표로 변환한다.
  /// 주소를 찾지 못하면 null을 반환한다.
  /// 네트워크/파싱 오류 시 [GeocodingException]을 throw한다.
  Future<LatLng?> geocode(String address) async {
    try {
      final response = await dio.get(
        _geocodeUrl,
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
      // ignore: avoid_print
      print('[LeaveNow] geocode DioException: status=${e.response?.statusCode} msg=${e.message}');
      throw GeocodingException('네트워크 오류: ${e.message}');
    }
  }
}
