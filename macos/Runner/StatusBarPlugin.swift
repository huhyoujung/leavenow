import Cocoa
import FlutterMacOS

class StatusBarPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
  private static var shared: StatusBarPlugin?

  private let channel: FlutterMethodChannel
  private var statusItem: NSStatusItem?
  private var menuKeys: [Int: String] = [:]  // tag → key 매핑

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  private func ensureStatusItem() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.title = "🚌"
    self.statusItem = item
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.leavenow/statusbar",
      binaryMessenger: registrar.messenger
    )
    let instance = StatusBarPlugin(channel: channel)
    shared = instance
    registrar.addMethodCallDelegate(instance, channel: channel)

    DispatchQueue.main.async {
      instance.ensureStatusItem()
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setTitle":
      if let args = call.arguments as? [String: Any],
         let title = args["title"] as? String {
        ensureStatusItem()
        statusItem?.length = NSStatusItem.variableLength
        statusItem?.button?.title = title
      }
      result(nil)

    case "setMenu":
      if let args = call.arguments as? [String: Any],
         let items = args["items"] as? [[String: Any]] {
        ensureStatusItem()
        buildMenu(items)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func buildMenu(_ items: [[String: Any]]) {
    guard let statusItem = statusItem else { return }
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    menuKeys.removeAll()

    var tag = 100
    for item in items {
      let type = item["type"] as? String ?? "item"
      if type == "separator" {
        menu.addItem(.separator())
        continue
      }
      let label = item["label"] as? String ?? ""
      let key = item["key"] as? String
      let disabled = item["disabled"] as? Bool ?? false

      let menuItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
      menuItem.isEnabled = !disabled
      menuItem.tag = tag

      if let key = key, !disabled {
        menuKeys[tag] = key
        // action과 target 설정
        menuItem.action = #selector(menuItemClicked(_:))
        menuItem.target = self
      }

      menu.addItem(menuItem)
      tag += 1
    }
    statusItem.menu = menu
  }

  func menuWillOpen(_ menu: NSMenu) {}

  // NSMenuDelegate - 메뉴가 닫힌 후 menu를 재설정하여 다음 클릭 정상 동작
  func menuDidClose(_ menu: NSMenu) {
    DispatchQueue.main.async { [weak self] in
      self?.statusItem?.menu = menu
    }
  }

  @objc func menuItemClicked(_ sender: NSMenuItem) {
    guard let key = menuKeys[sender.tag] else { return }
    channel.invokeMethod("onMenuItemClick", arguments: ["key": key])
  }
}
