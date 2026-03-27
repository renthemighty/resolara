import Flutter
import UIKit
import PDFKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "resolara.ai/pdf_text",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      guard call.method == "extractText",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
        return
      }
      let url = URL(fileURLWithPath: path)
      guard let doc = PDFDocument(url: url) else {
        result("")
        return
      }
      var text = ""
      for i in 0..<doc.pageCount {
        if let page = doc.page(at: i), let pageText = page.string, !pageText.isEmpty {
          if !text.isEmpty { text += "\n" }
          text += pageText
        }
      }
      result(text)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
