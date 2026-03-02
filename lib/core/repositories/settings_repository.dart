// 사용자 설정 (정류장 번호, 시간 기준) SharedPreferences 저장/불러오기
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyHomeArsId = 'home_ars_id';
  static const _keyWorkArsId = 'work_ars_id';
  static const _keyTimeThreshold = 'time_threshold_hour';

  final SharedPreferences prefs;

  SettingsRepository({required this.prefs});

  String? get homeArsId => prefs.getString(_keyHomeArsId);
  String? get workArsId => prefs.getString(_keyWorkArsId);
  int get timeThresholdHour => prefs.getInt(_keyTimeThreshold) ?? 15;
  bool get isConfigured => homeArsId != null && workArsId != null;

  Future<void> saveHomeArsId(String arsId) =>
      prefs.setString(_keyHomeArsId, arsId);

  Future<void> saveWorkArsId(String arsId) =>
      prefs.setString(_keyWorkArsId, arsId);

  Future<void> saveTimeThresholdHour(int hour) =>
      prefs.setInt(_keyTimeThreshold, hour);
}
