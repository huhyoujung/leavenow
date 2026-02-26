# LeaveNow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** macOS 메뉴바에서 출퇴근 버스/지하철 다음 출발 시간을 자동으로 보여주는 Flutter 앱 구현

**Architecture:** Core 레이어(서비스/모델)를 플랫폼 독립적으로 설계하고, macOS 메뉴바 UI는 `tray_manager` 패키지로 구현. 시나리오(출근/퇴근)는 GPS → 시간 → 수동 순서로 자동 감지.

**Tech Stack:** Flutter (macOS), tray_manager, geolocator, dio, shared_preferences, flutter_dotenv, mocktail

---

## 사전 확인 사항

- Naver Cloud Platform에서 아래 두 API가 활성화되어 있는지 확인:
  - **Maps - Geocoding** (주소 → 좌표)
  - **Maps - Directions** (대중교통 경로 탐색)
- API 키: Client ID / Client Secret (`.env`에 보관, 절대 커밋 금지)

---

## Task 1: Flutter 프로젝트 생성 + 의존성 설정

**Files:**
- Create: `leavenow/` (Flutter 프로젝트 루트)
- Modify: `pubspec.yaml`
- Create: `.env`
- Create: `.gitignore`
- Modify: `macos/Runner/DebugProfile.entitlements`
- Modify: `macos/Runner/Release.entitlements`
- Modify: `macos/Runner/Info.plist`

**Step 1: Flutter 프로젝트 생성**

```bash
cd /Users/huhyoujung/dev/leavenow
flutter create . --platforms=macos --org com.leavenow
```

Expected: macOS 프로젝트 파일 생성됨

**Step 2: pubspec.yaml에 의존성 추가**

`pubspec.yaml`의 `dependencies` 섹션을 아래로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter
  tray_manager: ^0.2.3
  geolocator: ^13.0.0
  dio: ^5.7.0
  shared_preferences: ^2.3.0
  flutter_dotenv: ^5.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  flutter_lints: ^5.0.0
```

**Step 3: 패키지 설치**

```bash
flutter pub get
```

Expected: 의존성 설치 완료, 오류 없음

**Step 4: .env 파일 생성**

```
NAVER_CLIENT_ID=5o9mxqw9sm
NAVER_CLIENT_SECRET=cUduhtMtqANed0aH6cmBvgIzXF7isRLUwwxRpn6M
```

**Step 5: .env를 pubspec assets에 등록**

`pubspec.yaml`에 추가:
```yaml
flutter:
  assets:
    - .env
```

**Step 6: .gitignore에 .env 추가**

`.gitignore`에 아래 줄 추가:
```
.env
```

**Step 7: macOS entitlements에 네트워크 + 위치 권한 추가**

`macos/Runner/DebugProfile.entitlements`와 `macos/Runner/Release.entitlements` 둘 다:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.personal-information.location</key>
<true/>
```

**Step 8: Info.plist에 위치 사용 설명 추가**

`macos/Runner/Info.plist`에 추가:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>현재 위치를 감지하여 출근/퇴근 모드를 자동으로 설정합니다.</string>
```

**Step 9: 앱이 빌드되는지 확인**

```bash
flutter build macos
```

Expected: Build succeeded

**Step 10: Commit**

```bash
git add .
git commit -m "feat: Flutter 프로젝트 초기 설정 (macOS, 의존성, 권한)"
```

---

## Task 2: Core 모델 정의

**Files:**
- Create: `lib/core/models/departure.dart`
- Create: `lib/core/models/transit_route.dart`
- Create: `test/core/models/departure_test.dart`
- Create: `test/core/models/transit_route_test.dart`

**Step 1: 실패하는 테스트 작성 (departure)**

`test/core/models/departure_test.dart`:
```dart
// Departure 모델 단위 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/models/departure.dart';

void main() {
  group('Departure', () {
    test('남은 분 계산', () {
      final now = DateTime(2026, 2, 26, 8, 30);
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.minutesUntil(now), 12);
    });

    test('출발했으면 음수 반환', () {
      final now = DateTime(2026, 2, 26, 8, 50);
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.minutesUntil(now), -8);
    });

    test('displayLabel: 버스는 노선 번호 표시', () {
      final departure = Departure(
        routeName: '9401',
        transportType: TransportType.bus,
        departureTime: DateTime(2026, 2, 26, 8, 42),
      );

      expect(departure.displayLabel, '🚌 9401');
    });

    test('displayLabel: 지하철은 호선 표시', () {
      final departure = Departure(
        routeName: '2호선',
        transportType: TransportType.subway,
        departureTime: DateTime(2026, 2, 26, 8, 49),
      );

      expect(departure.displayLabel, '🚇 2호선');
    });
  });
}
```

**Step 2: 테스트 실행 → 실패 확인**

```bash
flutter test test/core/models/departure_test.dart
```

Expected: FAIL (파일 없음)

**Step 3: Departure 모델 구현**

`lib/core/models/departure.dart`:
```dart
// 하나의 출발 교통편 정보 (노선명, 수단, 출발 시각)
enum TransportType { bus, subway }

class Departure {
  final String routeName;
  final TransportType transportType;
  final DateTime departureTime;

  const Departure({
    required this.routeName,
    required this.transportType,
    required this.departureTime,
  });

  int minutesUntil(DateTime now) {
    return departureTime.difference(now).inMinutes;
  }

  String get displayLabel {
    final icon = transportType == TransportType.bus ? '🚌' : '🚇';
    return '$icon $routeName';
  }
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/core/models/departure_test.dart
```

Expected: All tests PASS

**Step 5: TransitRoute 모델 테스트 작성**

`test/core/models/transit_route_test.dart`:
```dart
// TransitRoute 모델 단위 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/models/transit_route.dart';

void main() {
  group('TransitRoute', () {
    test('다음 출발편 N개 반환', () {
      final now = DateTime(2026, 2, 26, 8, 30);
      final route = TransitRoute(
        id: 'route-1',
        departures: [
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 8, 42),
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 3),
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 24),
          ),
        ],
      );

      final upcoming = route.upcomingDepartures(now, limit: 2);
      expect(upcoming.length, 2);
      expect(upcoming.first.minutesUntil(now), 12);
    });

    test('이미 출발한 편은 제외', () {
      final now = DateTime(2026, 2, 26, 8, 50);
      final route = TransitRoute(
        id: 'route-1',
        departures: [
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 8, 42), // 이미 출발
          ),
          Departure(
            routeName: '9401',
            transportType: TransportType.bus,
            departureTime: DateTime(2026, 2, 26, 9, 3),
          ),
        ],
      );

      final upcoming = route.upcomingDepartures(now);
      expect(upcoming.length, 1);
      expect(upcoming.first.minutesUntil(now), 13);
    });
  });
}
```

**Step 6: TransitRoute 모델 구현**

`lib/core/models/transit_route.dart`:
```dart
// 하나의 대중교통 경로 (출발편 목록 포함)
import 'departure.dart';

class TransitRoute {
  final String id;
  final List<Departure> departures;

  const TransitRoute({
    required this.id,
    required this.departures,
  });

  List<Departure> upcomingDepartures(DateTime now, {int limit = 3}) {
    return departures
        .where((d) => d.minutesUntil(now) >= 0)
        .take(limit)
        .toList();
  }
}
```

**Step 7: 테스트 통과 확인**

```bash
flutter test test/core/models/
```

Expected: All tests PASS

**Step 8: Commit**

```bash
git add lib/core/models/ test/core/models/
git commit -m "feat: Departure, TransitRoute 핵심 모델 추가"
```

---

## Task 3: NaverGeocodingService (주소 → 좌표)

**Files:**
- Create: `lib/core/services/naver_geocoding_service.dart`
- Create: `test/core/services/naver_geocoding_service_test.dart`

> **참고:** Naver Geocoding API 문서 확인
> - URL: `https://maps.apigw.ntruss.com/map-geocode/v2/geocode`
> - Headers: `X-NCP-APIGW-API-KEY-ID`, `X-NCP-APIGW-API-KEY`
> - 응답에서 `addresses[0].x` (경도), `addresses[0].y` (위도) 추출

**Step 1: 실패하는 테스트 작성**

`test/core/services/naver_geocoding_service_test.dart`:
```dart
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
          requestOptions: RequestOptions(),
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
          requestOptions: RequestOptions(),
        ));

    final result = await service.geocode('존재하지않는주소abc');
    expect(result, isNull);
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/core/services/naver_geocoding_service_test.dart
```

Expected: FAIL

**Step 3: 서비스 구현**

`lib/core/services/naver_geocoding_service.dart`:
```dart
// 네이버 Geocoding API로 주소를 위경도 좌표로 변환
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});
}

class NaverGeocodingService {
  static const _baseUrl = 'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';

  final Dio dio;

  NaverGeocodingService({required this.dio});

  Future<LatLng?> geocode(String address) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {'query': address},
      options: Options(headers: {
        'X-NCP-APIGW-API-KEY-ID': dotenv.env['NAVER_CLIENT_ID']!,
        'X-NCP-APIGW-API-KEY': dotenv.env['NAVER_CLIENT_SECRET']!,
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
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/core/services/naver_geocoding_service_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/core/services/naver_geocoding_service.dart test/core/services/
git commit -m "feat: NaverGeocodingService 주소→좌표 변환"
```

---

## Task 4: NaverTransitService (대중교통 경로 탐색)

**Files:**
- Create: `lib/core/services/naver_transit_service.dart`
- Create: `test/core/services/naver_transit_service_test.dart`

> **참고:** Naver Directions - 대중교통 API 문서 확인
> - URL 및 응답 형식 확인 필요 (NCP 콘솔 → Maps → Directions)
> - 응답에서 각 경로의 출발 시간, 교통 수단, 노선명 파싱

**Step 1: 실제 API 응답 샘플 확인**

```bash
curl -X GET "https://maps.apigw.ntruss.com/map-direction/v1/transit?\
start=127.028,37.498&goal=126.978,37.566" \
-H "X-NCP-APIGW-API-KEY-ID: 5o9mxqw9sm" \
-H "X-NCP-APIGW-API-KEY: cUduhtMtqANed0aH6cmBvgIzXF7isRLUwwxRpn6M"
```

> 실제 응답 JSON 구조를 보고 아래 파싱 코드 조정 필요

**Step 2: 실패하는 테스트 작성**

`test/core/services/naver_transit_service_test.dart`:
```dart
// NaverTransitService 단위 테스트 (Dio mock)
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/models/transit_route.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/naver_transit_service.dart';

class MockDio extends Mock implements Dio {}

// 실제 API 응답 샘플로 교체 필요
const _mockResponse = {
  'code': 0,
  'route': {
    'traoptimal': [
      {
        'summary': {'duration': 2700},
        'legs': [
          {
            'mode': 'BUS',
            'route': '9401',
            'departureTime': '2026-02-26T08:42:00',
          },
        ],
      },
      {
        'summary': {'duration': 2400},
        'legs': [
          {
            'mode': 'SUBWAY',
            'route': '2호선',
            'departureTime': '2026-02-26T08:49:00',
          },
        ],
      },
    ]
  }
};

void main() {
  late MockDio mockDio;
  late NaverTransitService service;

  setUp(() {
    mockDio = MockDio();
    service = NaverTransitService(dio: mockDio);
  });

  test('경로 목록 반환', () async {
    when(() => mockDio.get(any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: _mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

    final routes = await service.fetchRoutes(
      origin: const LatLng(latitude: 37.498, longitude: 127.028),
      destination: const LatLng(latitude: 37.566, longitude: 126.978),
    );

    expect(routes.length, greaterThan(0));
    expect(routes.first.departures.first.routeName, '9401');
    expect(routes.first.departures.first.transportType, TransportType.bus);
  });
}
```

**Step 3: 서비스 구현**

`lib/core/services/naver_transit_service.dart`:
```dart
// 네이버 대중교통 경로 탐색 API 호출 및 TransitRoute 변환
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/departure.dart';
import '../models/transit_route.dart';
import 'naver_geocoding_service.dart';

class NaverTransitService {
  // TODO: NCP 콘솔에서 실제 대중교통 API 엔드포인트 확인
  static const _baseUrl = 'https://maps.apigw.ntruss.com/map-direction/v1/transit';

  final Dio dio;

  NaverTransitService({required this.dio});

  Future<List<TransitRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'start': '${origin.longitude},${origin.latitude}',
        'goal': '${destination.longitude},${destination.latitude}',
      },
      options: Options(headers: {
        'X-NCP-APIGW-API-KEY-ID': dotenv.env['NAVER_CLIENT_ID']!,
        'X-NCP-APIGW-API-KEY': dotenv.env['NAVER_CLIENT_SECRET']!,
      }),
    );

    // TODO: 실제 응답 구조에 맞게 파싱 로직 조정
    final rawRoutes = response.data['route']['traoptimal'] as List;

    return rawRoutes.asMap().entries.map((entry) {
      final legs = entry.value['legs'] as List;
      final departures = legs.map((leg) {
        final mode = leg['mode'] as String;
        return Departure(
          routeName: leg['route'] as String,
          transportType: mode == 'SUBWAY' ? TransportType.subway : TransportType.bus,
          departureTime: DateTime.parse(leg['departureTime'] as String),
        );
      }).toList();

      return TransitRoute(
        id: 'route-${entry.key}',
        departures: departures,
      );
    }).toList();
  }
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/core/services/naver_transit_service_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/core/services/naver_transit_service.dart test/core/services/naver_transit_service_test.dart
git commit -m "feat: NaverTransitService 대중교통 경로 탐색"
```

---

## Task 5: SettingsRepository (설정 저장/불러오기)

**Files:**
- Create: `lib/core/repositories/settings_repository.dart`
- Create: `test/core/repositories/settings_repository_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/core/repositories/settings_repository_test.dart`:
```dart
// SettingsRepository 단위 테스트 (SharedPreferences mock)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leavenow/core/repositories/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('집/회사 주소 저장 후 불러오기', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());

    await repo.saveHomeAddress('경기도 성남시 분당구 판교역로 1');
    await repo.saveWorkAddress('서울시 강남구 테헤란로 123');

    expect(repo.homeAddress, '경기도 성남시 분당구 판교역로 1');
    expect(repo.workAddress, '서울시 강남구 테헤란로 123');
  });

  test('대표 루트 ID 저장 후 불러오기', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());

    await repo.savePreferredRouteId('route-0');
    expect(repo.preferredRouteId, 'route-0');
  });

  test('시간 기준 기본값은 15 (오후 3시)', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());
    expect(repo.timeThresholdHour, 15);
  });

  test('시간 기준 변경 저장', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());
    await repo.saveTimeThresholdHour(14);
    expect(repo.timeThresholdHour, 14);
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/core/repositories/settings_repository_test.dart
```

**Step 3: SettingsRepository 구현**

`lib/core/repositories/settings_repository.dart`:
```dart
// 사용자 설정 (주소, 대표 루트, 시간 기준) SharedPreferences 저장/불러오기
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyHome = 'home_address';
  static const _keyWork = 'work_address';
  static const _keyPreferredRoute = 'preferred_route_id';
  static const _keyTimeThreshold = 'time_threshold_hour';

  final SharedPreferences prefs;

  SettingsRepository({required this.prefs});

  String? get homeAddress => prefs.getString(_keyHome);
  String? get workAddress => prefs.getString(_keyWork);
  String? get preferredRouteId => prefs.getString(_keyPreferredRoute);
  int get timeThresholdHour => prefs.getInt(_keyTimeThreshold) ?? 15;

  Future<void> saveHomeAddress(String address) =>
      prefs.setString(_keyHome, address);

  Future<void> saveWorkAddress(String address) =>
      prefs.setString(_keyWork, address);

  Future<void> savePreferredRouteId(String id) =>
      prefs.setString(_keyPreferredRoute, id);

  Future<void> saveTimeThresholdHour(int hour) =>
      prefs.setInt(_keyTimeThreshold, hour);

  bool get isConfigured => homeAddress != null && workAddress != null;
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/core/repositories/settings_repository_test.dart
```

**Step 5: Commit**

```bash
git add lib/core/repositories/ test/core/repositories/
git commit -m "feat: SettingsRepository 설정 저장/불러오기"
```

---

## Task 6: ScenarioService (출근/퇴근 자동 감지)

**Files:**
- Create: `lib/core/services/scenario_service.dart`
- Create: `test/core/services/scenario_service_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/core/services/scenario_service_test.dart`:
```dart
// ScenarioService 단위 테스트 - GPS/시간/수동 우선순위 검증
import 'package:flutter_test/flutter_test.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/scenario_service.dart';

void main() {
  const home = LatLng(latitude: 37.394, longitude: 127.111); // 판교
  const work = LatLng(latitude: 37.498, longitude: 127.028); // 강남

  group('GPS 기반 감지', () {
    test('집 반경 500m → 출근 모드', () {
      // 집에서 300m 떨어진 위치
      const current = LatLng(latitude: 37.3967, longitude: 127.111);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, Scenario.toWork);
    });

    test('회사 반경 500m → 퇴근 모드', () {
      // 회사에서 200m 떨어진 위치
      const current = LatLng(latitude: 37.4997, longitude: 127.028);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, Scenario.toHome);
    });

    test('범위 밖 → null 반환', () {
      const current = LatLng(latitude: 37.55, longitude: 127.00);
      final scenario = ScenarioService.detectByLocation(
        current: current,
        home: home,
        work: work,
      );
      expect(scenario, isNull);
    });
  });

  group('시간 기반 감지', () {
    test('오전 → 출근 모드', () {
      final time = DateTime(2026, 2, 26, 8, 30);
      expect(ScenarioService.detectByTime(time, thresholdHour: 15), Scenario.toWork);
    });

    test('오후 3시 이후 → 퇴근 모드', () {
      final time = DateTime(2026, 2, 26, 17, 0);
      expect(ScenarioService.detectByTime(time, thresholdHour: 15), Scenario.toHome);
    });
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/core/services/scenario_service_test.dart
```

**Step 3: ScenarioService 구현**

`lib/core/services/scenario_service.dart`:
```dart
// 출근/퇴근 시나리오 판단: GPS → 시간 → 수동 우선순위
import 'dart:math';
import 'naver_geocoding_service.dart';

enum Scenario { toWork, toHome }

class ScenarioService {
  static const _radiusMeters = 500.0;

  /// GPS 위치로 시나리오 판단. 범위 밖이면 null 반환.
  static Scenario? detectByLocation({
    required LatLng current,
    required LatLng home,
    required LatLng work,
  }) {
    if (_distanceMeters(current, home) <= _radiusMeters) return Scenario.toWork;
    if (_distanceMeters(current, work) <= _radiusMeters) return Scenario.toHome;
    return null;
  }

  /// 시간으로 시나리오 판단
  static Scenario detectByTime(DateTime time, {required int thresholdHour}) {
    return time.hour < thresholdHour ? Scenario.toWork : Scenario.toHome;
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final c = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLon * sinDLon;
    return earthRadius * 2 * atan2(sqrt(c), sqrt(1 - c));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/core/services/scenario_service_test.dart
```

**Step 5: Commit**

```bash
git add lib/core/services/scenario_service.dart test/core/services/scenario_service_test.dart
git commit -m "feat: ScenarioService GPS/시간 기반 출퇴근 시나리오 감지"
```

---

## Task 7: AppController (전체 상태 관리)

**Files:**
- Create: `lib/core/app_controller.dart`
- Create: `test/core/app_controller_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/core/app_controller_test.dart`:
```dart
// AppController 단위 테스트 - 서비스 통합 및 상태 관리
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leavenow/core/app_controller.dart';
import 'package:leavenow/core/models/departure.dart';
import 'package:leavenow/core/models/transit_route.dart';
import 'package:leavenow/core/services/naver_transit_service.dart';
import 'package:leavenow/core/services/naver_geocoding_service.dart';
import 'package:leavenow/core/services/scenario_service.dart';

class MockNaverTransitService extends Mock implements NaverTransitService {}
class MockNaverGeocodingService extends Mock implements NaverGeocodingService {}

void main() {
  late MockNaverTransitService mockTransit;
  late MockNaverGeocodingService mockGeocode;

  setUp(() {
    mockTransit = MockNaverTransitService();
    mockGeocode = MockNaverGeocodingService();

    registerFallbackValue(const LatLng(latitude: 0, longitude: 0));
  });

  test('경로 로드 후 preferredRoute가 설정됨', () async {
    when(() => mockGeocode.geocode(any()))
        .thenAnswer((_) async => const LatLng(latitude: 37.394, longitude: 127.111));

    when(() => mockTransit.fetchRoutes(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
        )).thenAnswer((_) async => [
          TransitRoute(
            id: 'route-0',
            departures: [
              Departure(
                routeName: '9401',
                transportType: TransportType.bus,
                departureTime: DateTime.now().add(const Duration(minutes: 10)),
              ),
            ],
          ),
        ]);

    final controller = AppController(
      transitService: mockTransit,
      geocodingService: mockGeocode,
      scenario: Scenario.toWork,
      homeAddress: '판교',
      workAddress: '강남',
      preferredRouteId: null,
    );

    await controller.loadRoutes();

    expect(controller.routes.isNotEmpty, true);
    expect(controller.preferredRoute, isNotNull);
  });
}
```

**Step 2: AppController 구현**

`lib/core/app_controller.dart`:
```dart
// 앱 전체 상태 관리 - 시나리오, 경로 목록, 대표 루트
import 'models/transit_route.dart';
import 'services/naver_geocoding_service.dart';
import 'services/naver_transit_service.dart';
import 'services/scenario_service.dart';

class AppController {
  final NaverTransitService transitService;
  final NaverGeocodingService geocodingService;

  Scenario scenario;
  final String homeAddress;
  final String workAddress;
  String? preferredRouteId;

  List<TransitRoute> routes = [];

  AppController({
    required this.transitService,
    required this.geocodingService,
    required this.scenario,
    required this.homeAddress,
    required this.workAddress,
    required this.preferredRouteId,
  });

  TransitRoute? get preferredRoute {
    if (routes.isEmpty) return null;
    return routes.firstWhere(
      (r) => r.id == preferredRouteId,
      orElse: () => routes.first,
    );
  }

  Future<void> loadRoutes() async {
    final origin = scenario == Scenario.toWork ? homeAddress : workAddress;
    final destination = scenario == Scenario.toWork ? workAddress : homeAddress;

    final originCoord = await geocodingService.geocode(origin);
    final destCoord = await geocodingService.geocode(destination);

    if (originCoord == null || destCoord == null) return;

    routes = await transitService.fetchRoutes(
      origin: originCoord,
      destination: destCoord,
    );
  }

  void toggleScenario() {
    scenario = scenario == Scenario.toWork ? Scenario.toHome : Scenario.toWork;
  }
}
```

**Step 3: 테스트 통과 확인**

```bash
flutter test test/core/app_controller_test.dart
```

**Step 4: Commit**

```bash
git add lib/core/app_controller.dart test/core/app_controller_test.dart
git commit -m "feat: AppController 상태 관리 및 경로 로드"
```

---

## Task 8: macOS 메뉴바 UI

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/platforms/macos/menu_bar_app.dart`
- Create: `assets/tray_icon.png` (16x16 또는 22x22 흑백 아이콘)

**Step 1: 트레이 아이콘 준비**

`assets/` 디렉토리에 `tray_icon.png` 파일 추가 (16x16, 흑백 버스 아이콘).
macOS는 Template Image를 지원하므로 파일명을 `tray_iconTemplate.png`로 해도 됨.

`pubspec.yaml`에 추가:
```yaml
flutter:
  assets:
    - .env
    - assets/tray_icon.png
```

**Step 2: main.dart 수정**

`lib/main.dart`:
```dart
// macOS 메뉴바 앱 진입점
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/repositories/settings_repository.dart';
import 'platforms/macos/menu_bar_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs: prefs);

  runApp(MenuBarApp(settings: settings));
}
```

**Step 3: MenuBarApp 구현**

`lib/platforms/macos/menu_bar_app.dart`:
```dart
// macOS 메뉴바 앱 - tray_manager로 상태 표시 및 드롭다운 제공
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_controller.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/naver_geocoding_service.dart';
import '../../core/services/naver_transit_service.dart';
import '../../core/services/scenario_service.dart';

class MenuBarApp extends StatefulWidget {
  final SettingsRepository settings;
  const MenuBarApp({super.key, required this.settings});

  @override
  State<MenuBarApp> createState() => _MenuBarAppState();
}

class _MenuBarAppState extends State<MenuBarApp> with TrayListener {
  late AppController _controller;
  bool _manualOverride = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initController();
  }

  Future<void> _initController() async {
    final scenario = await _detectScenario();
    final dio = Dio();
    _controller = AppController(
      transitService: NaverTransitService(dio: dio),
      geocodingService: NaverGeocodingService(dio: dio),
      scenario: scenario,
      homeAddress: widget.settings.homeAddress ?? '',
      workAddress: widget.settings.workAddress ?? '',
      preferredRouteId: widget.settings.preferredRouteId,
    );
    await _refresh();
  }

  Future<Scenario> _detectScenario() async {
    if (!_manualOverride) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
        final current = LatLng(latitude: pos.latitude, longitude: pos.longitude);
        // TODO: 집/회사 좌표는 설정에서 캐시
        // 여기서는 시간 기반 폴백 사용
      } catch (_) {}
    }
    return ScenarioService.detectByTime(
      DateTime.now(),
      thresholdHour: widget.settings.timeThresholdHour,
    );
  }

  Future<void> _refresh() async {
    if (!widget.settings.isConfigured) {
      await _updateTrayTitle('⚙️ 설정 필요');
      return;
    }

    await _controller.loadRoutes();
    await _updateTrayFromController();
    await _scheduleNextRefresh();
  }

  Future<void> _updateTrayFromController() async {
    final preferred = _controller.preferredRoute;
    if (preferred == null) {
      await _updateTrayTitle('버스 정보 없음');
      return;
    }

    final upcoming = preferred.upcomingDepartures(DateTime.now(), limit: 1);
    if (upcoming.isEmpty) {
      await _updateTrayTitle('운행 종료');
      return;
    }

    final next = upcoming.first;
    final label = '${next.displayLabel} ${next.minutesUntil(DateTime.now())}분';
    await _updateTrayTitle(label);
    await _buildContextMenu();
  }

  Future<void> _updateTrayTitle(String title) async {
    await trayManager.setIcon('assets/tray_icon.png');
    await trayManager.setTitle(title);
  }

  Future<void> _buildContextMenu() async {
    final items = <MenuItem>[];
    final scenarioLabel = _controller.scenario == Scenario.toWork ? '출근 중' : '퇴근 중';
    final toggleLabel = _controller.scenario == Scenario.toWork ? '퇴근 모드로 전환' : '출근 모드로 전환';

    items.add(MenuItem(label: scenarioLabel, disabled: true));
    items.add(MenuItem.separator());

    // 대표 루트 출발편
    final preferred = _controller.preferredRoute;
    if (preferred != null) {
      items.add(MenuItem(label: '★ 대표 루트', disabled: true));
      for (final d in preferred.upcomingDepartures(DateTime.now())) {
        items.add(MenuItem(
          label: '${d.displayLabel}  ${d.minutesUntil(DateTime.now())}분 후',
          disabled: true,
        ));
      }
    }

    // 기타 루트
    final others = _controller.routes.where((r) => r.id != preferred?.id);
    if (others.isNotEmpty) {
      items.add(MenuItem.separator());
      items.add(MenuItem(label: '기타 루트', disabled: true));
      for (final route in others) {
        final next = route.upcomingDepartures(DateTime.now(), limit: 1);
        if (next.isNotEmpty) {
          items.add(MenuItem(
            label: '${next.first.displayLabel}  ${next.first.minutesUntil(DateTime.now())}분 후',
            disabled: true,
          ));
        }
      }
    }

    items.add(MenuItem.separator());
    items.add(MenuItem(label: toggleLabel, key: 'toggle'));
    items.add(MenuItem(label: '새로고침', key: 'refresh'));
    items.add(MenuItem(label: '설정', key: 'settings'));

    await trayManager.setContextMenu(Menu(items: items));
  }

  Future<void> _scheduleNextRefresh() async {
    // 다음 출발 2분 전에 갱신 (TODO: Timer로 정확히 구현)
    Future.delayed(const Duration(minutes: 2), _refresh);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        _manualOverride = true;
        _controller.toggleScenario();
        _refresh();
      case 'refresh':
        _refresh();
      case 'settings':
        // TODO: Task 9에서 구현
        break;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }
}
```

**Step 4: 앱 실행 확인**

```bash
flutter run -d macos
```

Expected: 메뉴바에 아이콘과 텍스트 표시됨. 설정이 없으면 "⚙️ 설정 필요" 표시.

**Step 5: Commit**

```bash
git add lib/ assets/
git commit -m "feat: macOS 메뉴바 UI 구현 (tray_manager)"
```

---

## Task 9: 설정 화면

**Files:**
- Create: `lib/platforms/macos/settings_window.dart`

> 설정 화면은 별도 창(window)으로 띄우거나, tray 드롭다운 내 간단한 입력 폼으로 구현 가능.
> macOS에서 별도 창을 띄우려면 `window_manager` 패키지 추가 필요.

**Step 1: window_manager 의존성 추가**

`pubspec.yaml`에 추가:
```yaml
  window_manager: ^0.4.3
```

```bash
flutter pub get
```

**Step 2: 설정 화면 구현**

`lib/platforms/macos/settings_window.dart`:
```dart
// 집/회사 주소 및 대표 루트 설정 화면
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/repositories/settings_repository.dart';

class SettingsWindow extends StatefulWidget {
  final SettingsRepository settings;
  const SettingsWindow({super.key, required this.settings});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  late TextEditingController _homeCtrl;
  late TextEditingController _workCtrl;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: widget.settings.homeAddress ?? '');
    _workCtrl = TextEditingController(text: widget.settings.workAddress ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LeaveNow 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('집 주소'),
              TextField(controller: _homeCtrl),
              const SizedBox(height: 16),
              const Text('회사 주소'),
              TextField(controller: _workCtrl),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    await widget.settings.saveHomeAddress(_homeCtrl.text.trim());
    await widget.settings.saveWorkAddress(_workCtrl.text.trim());
    await windowManager.hide();
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _workCtrl.dispose();
    super.dispose();
  }
}
```

**Step 3: MenuBarApp에서 설정 창 열기 연결**

`menu_bar_app.dart`의 `case 'settings':` 부분 수정:
```dart
case 'settings':
  await windowManager.show();
  await windowManager.focus();
```

`main.dart`에 window_manager 초기화 추가:
```dart
await windowManager.ensureInitialized();
WindowOptions windowOptions = const WindowOptions(
  size: Size(400, 300),
  title: 'LeaveNow 설정',
  skipTaskbar: false,
);
await windowManager.waitUntilReadyToShow(windowOptions, () async {
  await windowManager.hide(); // 시작 시 숨김
});
```

**Step 4: 전체 테스트**

```bash
flutter run -d macos
```

Expected:
1. 트레이 아이콘 클릭 → 드롭다운
2. "설정" 클릭 → 설정 창 오픈
3. 주소 입력 저장 → 트레이에 다음 출발 표시

**Step 5: Commit**

```bash
git add lib/platforms/macos/settings_window.dart lib/main.dart
git commit -m "feat: 설정 화면 및 window_manager 연동"
```

---

## Task 10: 전체 통합 테스트 및 마무리

**Step 1: 전체 테스트 실행**

```bash
flutter test
```

Expected: All tests PASS

**Step 2: macOS 릴리즈 빌드 확인**

```bash
flutter build macos --release
```

**Step 3: .gitignore 최종 확인**

`.gitignore`에 포함 여부 확인:
```
.env
build/
*.g.dart
```

**Step 4: 최종 Commit**

```bash
git add .
git commit -m "feat: LeaveNow macOS 메뉴바 앱 MVP 완성"
```

---

## 주의사항

1. **API 키 보안**: `.env` 파일은 절대 커밋하지 않는다. `.gitignore` 반드시 확인.
2. **Naver API 응답 형식**: Task 4에서 실제 API 응답을 curl로 확인 후 파싱 코드 조정 필요.
3. **macOS 권한**: 처음 실행 시 위치 권한 요청 다이얼로그가 표시됨. 거부하면 시간 기반으로 폴백.
4. **배차 시간 실시간성**: 네이버 경로 탐색 API는 스케줄 기반이므로 실시간 버스 위치와 다를 수 있음.
