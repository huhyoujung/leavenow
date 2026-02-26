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

  test('설정 미완료 시 isConfigured false', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());
    expect(repo.isConfigured, false);
  });

  test('집+회사 주소 모두 있으면 isConfigured true', () async {
    final repo = SettingsRepository(prefs: await SharedPreferences.getInstance());
    await repo.saveHomeAddress('판교');
    await repo.saveWorkAddress('강남');
    expect(repo.isConfigured, true);
  });
}
