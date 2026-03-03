// 정류장 번호 설정 화면 (macOS 별도 창)
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/repositories/settings_repository.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                mainAxisSize: MainAxisSize.min,
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
                          '정류장 번호(arsId)를 입력하세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '버스 정류장 표지판의 5자리 번호 (예: 14004)\n'
                          '네이버 지도에서 정류장 검색 → 상세정보의 ID로도 확인 가능',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAEAEB2),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          label: '출근 — 집 근처 정류장 번호',
                          icon: Icons.business_rounded,
                          controller: _homeCtrl,
                          hintText: '14004',
                          errorText: _homeError,
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          label: '출근 — 탈 버스 노선 (쉼표로 구분)',
                          icon: Icons.directions_bus_rounded,
                          controller: _homeRoutesCtrl,
                          hintText: '343, 4412',
                          errorText: null,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: '퇴근 — 회사 근처 정류장 번호',
                          icon: Icons.home_rounded,
                          controller: _workCtrl,
                          hintText: '14004',
                          errorText: _workError,
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          label: '퇴근 — 탈 버스 노선 (쉼표로 구분)',
                          icon: Icons.directions_bus_rounded,
                          controller: _workRoutesCtrl,
                          hintText: '343, 4412',
                          errorText: null,
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
          const Expanded(child: SizedBox()),
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
          keyboardType: TextInputType.number,
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

    await widget.settings.saveHomeArsId(home);
    await widget.settings.saveWorkArsId(work);
    await widget.settings.saveHomeRoutes(_homeRoutesCtrl.text.trim());
    await widget.settings.saveWorkRoutes(_workRoutesCtrl.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);

    widget.onSaved();
    await windowManager.hide();
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
