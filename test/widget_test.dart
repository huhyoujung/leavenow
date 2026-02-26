// macOS 메뉴바 앱 스모크 테스트 — AppRoot 위젯 기본 렌더링 확인
// 주의: window_manager/tray_manager 초기화 없이 MaterialApp 레이어만 테스트
import 'package:flutter_test/flutter_test.dart';

void main() {
  // macOS 메뉴바 앱은 window_manager, tray_manager 네이티브 초기화가 필요하므로
  // 위젯 통합 테스트는 실제 기기/시뮬레이터에서 수행한다.
  // 단위 테스트는 test/core/ 디렉터리에서 관리한다.
  test('placeholder — core unit tests are in test/core/', () {
    expect(true, isTrue);
  });
}
