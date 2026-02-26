// 집/회사 주소 설정 화면 (macOS 별도 창)
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: widget.settings.homeAddress ?? '');
    _workCtrl = TextEditingController(text: widget.settings.workAddress ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'LeaveNow 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('집 주소', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _homeCtrl,
              decoration: const InputDecoration(
                hintText: '예: 경기도 성남시 분당구 판교역로 1',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('회사 주소', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _workCtrl,
              decoration: const InputDecoration(
                hintText: '예: 서울시 강남구 테헤란로 123',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중...' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final home = _homeCtrl.text.trim();
    final work = _workCtrl.text.trim();
    if (home.isEmpty || work.isEmpty) return;

    setState(() => _saving = true);
    await widget.settings.saveHomeAddress(home);
    await widget.settings.saveWorkAddress(work);
    setState(() => _saving = false);

    widget.onSaved();
    await windowManager.hide();
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _workCtrl.dispose();
    super.dispose();
  }
}
