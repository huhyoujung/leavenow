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
  bool get isConfigured => homeAddress != null && workAddress != null;

  Future<void> saveHomeAddress(String address) =>
      prefs.setString(_keyHome, address);

  Future<void> saveWorkAddress(String address) =>
      prefs.setString(_keyWork, address);

  Future<void> savePreferredRouteId(String id) =>
      prefs.setString(_keyPreferredRoute, id);

  Future<void> saveTimeThresholdHour(int hour) =>
      prefs.setInt(_keyTimeThreshold, hour);
}
