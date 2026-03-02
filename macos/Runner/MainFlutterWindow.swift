import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 메뉴바 앱이므로 Flutter 윈도우 시작 시 숨김
    self.orderOut(nil)

    RegisterGeneratedPlugins(registry: flutterViewController)
    StatusBarPlugin.register(with: flutterViewController.registrar(forPlugin: "StatusBarPlugin"))

    super.awakeFromNib()
  }
}
