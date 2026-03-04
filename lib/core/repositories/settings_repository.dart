// 사용자 설정 (정류장 번호, 노선 필터, 시간 기준) SharedPreferences 저장/불러오기
import 'package:shared_preferences/shared_preferences.dart';

enum StationType { seoul, gyeonggi }

class SettingsRepository {
  static const _keyHomeArsId = 'home_ars_id';
  static const _keyWorkArsId = 'work_ars_id';
  static const _keyHomeRoutes = 'home_routes';
  static const _keyWorkRoutes = 'work_routes';
  static const _keyTimeThreshold = 'time_threshold_hour';
  static const _keyHomeStationType = 'home_station_type';
  static const _keyWorkStationType = 'work_station_type';

  final SharedPreferences prefs;

  SettingsRepository({required this.prefs});

  String? get homeArsId => prefs.getString(_keyHomeArsId);
  String? get workArsId => prefs.getString(_keyWorkArsId);

  /// 출근 시 탈 버스 노선 목록 (쉼표 구분, 예: "343,4412")
  List<String> get homeRoutes => _parseRoutes(prefs.getString(_keyHomeRoutes));
  /// 퇴근 시 탈 버스 노선 목록
  List<String> get workRoutes => _parseRoutes(prefs.getString(_keyWorkRoutes));

  String get homeRoutesRaw => prefs.getString(_keyHomeRoutes) ?? '';
  String get workRoutesRaw => prefs.getString(_keyWorkRoutes) ?? '';

  int get timeThresholdHour => prefs.getInt(_keyTimeThreshold) ?? 15;
  bool get isConfigured => homeArsId != null && workArsId != null;

  StationType get homeStationType =>
      _parseStationType(prefs.getString(_keyHomeStationType));
  StationType get workStationType =>
      _parseStationType(prefs.getString(_keyWorkStationType));

  Future<void> saveHomeArsId(String arsId) =>
      prefs.setString(_keyHomeArsId, arsId);

  Future<void> saveWorkArsId(String arsId) =>
      prefs.setString(_keyWorkArsId, arsId);

  Future<void> saveHomeRoutes(String routes) =>
      prefs.setString(_keyHomeRoutes, routes);

  Future<void> saveWorkRoutes(String routes) =>
      prefs.setString(_keyWorkRoutes, routes);

  Future<void> saveTimeThresholdHour(int hour) =>
      prefs.setInt(_keyTimeThreshold, hour);

  Future<void> saveHomeStationType(StationType type) =>
      prefs.setString(_keyHomeStationType, type.name);

  Future<void> saveWorkStationType(StationType type) =>
      prefs.setString(_keyWorkStationType, type.name);

  List<String> _parseRoutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  StationType _parseStationType(String? raw) {
    if (raw == 'gyeonggi') return StationType.gyeonggi;
    return StationType.seoul;
  }
}
