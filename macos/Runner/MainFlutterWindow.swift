import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // phone-shaped window; the game letterboxes any other shape
    self.title = "goingUP"
    self.setContentSize(NSSize(width: 460, height: 860))
    self.contentMinSize = NSSize(width: 300, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
