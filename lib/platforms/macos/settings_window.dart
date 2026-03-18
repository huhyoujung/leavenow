// 정류장 번호 설정 화면 (macOS 별도 창)
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/seoul_bus_service.dart';
import '../../core/services/gbus_service.dart';

class SettingsWindow extends StatefulWidget {
  final SettingsRepository settings;
  final VoidCallback onSaved;

  const SettingsWindow({
    super.key,
    required this.settings,
    required this.onSaved,
  });

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  late TextEditingController _homeCtrl;
  late TextEditingController _workCtrl;
  late TextEditingController _homeRoutesCtrl;
  late TextEditingController _workRoutesCtrl;

  late StationType _homeStationType;
  late StationType _workStationType;

  bool _saving = false;
  String? _homeError;
  String? _workError;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: widget.settings.homeArsId ?? '');
    _workCtrl = TextEditingController(text: widget.settings.workArsId ?? '');
    _homeRoutesCtrl = TextEditingController(text: widget.settings.homeRoutesRaw);
    _workRoutesCtrl = TextEditingController(text: widget.settings.workRoutesRaw);
    _homeStationType = widget.settings.homeStationType;
    _workStationType = widget.settings.workStationType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  _buildTitleBar(),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        const Text(
                          '버스 정류장 정보를 입력하세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '서울: 정류장 표지판의 5자리 번호 · 경기: m.gbis.go.kr에서 정류장 검색 후 URL의 숫자',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAEAEB2),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '출근',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          label: '집 근처 정류장 번호',
                          icon: Icons.business_rounded,
                          controller: _homeCtrl,
                          hintText: _homeStationType == StationType.gyeonggi
                              ? '228000353'
                              : '14004',
                          errorText: _homeError,
                          isNumericOnly: _homeStationType == StationType.seoul,
                          stationType: _homeStationType,
                          onStationTypeChanged: (t) =>
                              setState(() => _homeStationType = t),
                          searchUrl: _homeStationType == StationType.gyeonggi
                              ? 'https://m.gbis.go.kr/search'
                              : 'https://map.naver.com/p/search/버스정류장',
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          label: '탈 버스 노선 (쉼표로 구분)',
                          icon: Icons.directions_bus_rounded,
                          controller: _homeRoutesCtrl,
                          hintText: '343, 4412',
                          errorText: null,
                          isNumericOnly: false,
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5EA)),
                        const SizedBox(height: 16),
                        const Text(
                          '퇴근',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          label: '회사 근처 정류장 번호',
                          icon: Icons.home_rounded,
                          controller: _workCtrl,
                          hintText: _workStationType == StationType.gyeonggi
                              ? '228000353'
                              : '14004',
                          errorText: _workError,
                          isNumericOnly: _workStationType == StationType.seoul,
                          stationType: _workStationType,
                          onStationTypeChanged: (t) =>
                              setState(() => _workStationType = t),
                          searchUrl: _workStationType == StationType.gyeonggi
                              ? 'https://m.gbis.go.kr/search'
                              : 'https://map.naver.com/p/search/버스정류장',
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          label: '탈 버스 노선 (쉼표로 구분)',
                          icon: Icons.directions_bus_rounded,
                          controller: _workRoutesCtrl,
                          hintText: '343, 4412',
                          errorText: null,
                          isNumericOnly: false,
                        ),
                        const SizedBox(height: 20),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 48,
      color: const Color(0xFFF5F5F7),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => windowManager.hide(),
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5F57),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Text(
              'LeaveNow 설정',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 31),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required String? errorText,
    bool isNumericOnly = true,
    StationType? stationType,
    ValueChanged<StationType>? onStationTypeChanged,
    String? searchUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
                letterSpacing: 0.2,
              ),
            ),
            if (searchUrl != null) ...[  
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(searchUrl)),
                child: const Text(
                  '검색',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF007AFF),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
            if (stationType != null && onStationTypeChanged != null) ...[  
              const Spacer(),
              _SegmentButton(
                options: const ['서울', '경기'],
                selectedIndex: stationType == StationType.seoul ? 0 : 1,
                onChanged: (i) => onStationTypeChanged(
                    i == 0 ? StationType.seoul : StationType.gyeonggi),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.2,
          ),
          keyboardType: isNumericOnly ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFFAEAEB2),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 11,
              color: Color(0xFFFF3B30),
            ),
          ),
          onChanged: (_) {
            if (errorText != null) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('저장'),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final home = _homeCtrl.text.trim();
    final work = _workCtrl.text.trim();

    setState(() {
      _homeError = home.isEmpty ? '정류장 번호를 입력하세요' : null;
      _workError = work.isEmpty ? '정류장 번호를 입력하세요' : null;
    });

    if (_homeError != null || _workError != null) return;

    setState(() => _saving = true);

    // 저장 전 정류장 & 노선 검증
    final seoulService = SeoulBusService(dio: Dio());
    final gbusService = GbusBusService(dio: Dio());
    final homeRoutes = _parseRouteInput(_homeRoutesCtrl.text);
    final workRoutes = _parseRouteInput(_workRoutesCtrl.text);

    final homeWarn = _homeStationType == StationType.gyeonggi
        ? await gbusService.validateStation(home, homeRoutes)
        : await seoulService.validateStation(home, homeRoutes);
    final workWarn = _workStationType == StationType.gyeonggi
        ? await gbusService.validateStation(work, workRoutes)
        : await seoulService.validateStation(work, workRoutes);

    if (!mounted) return;

    if (homeWarn != null || workWarn != null) {
      setState(() => _saving = false);
      final message = [
        if (homeWarn != null) '출근 정류장\n$homeWarn',
        if (workWarn != null) '퇴근 정류장\n$workWarn',
      ].join('\n\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ 정류장 확인 필요'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('다시 입력'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('그래도 저장'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _saving = true);
    }

    await widget.settings.saveHomeArsId(home);
    await widget.settings.saveWorkArsId(work);
    await widget.settings.saveHomeRoutes(_homeRoutesCtrl.text.trim());
    await widget.settings.saveWorkRoutes(_workRoutesCtrl.text.trim());
    await widget.settings.saveHomeStationType(_homeStationType);
    await widget.settings.saveWorkStationType(_workStationType);

    if (!mounted) return;
    setState(() => _saving = false);

    widget.onSaved();
    await windowManager.hide();
  }

  List<String> _parseRouteInput(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _workCtrl.dispose();
    _homeRoutesCtrl.dispose();
    _workRoutesCtrl.dispose();
    super.dispose();
  }
}

/// 서울 / 경기 선택용 소형 세그먼트 버튼
class _SegmentButton extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentButton({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFF8E8E93),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
