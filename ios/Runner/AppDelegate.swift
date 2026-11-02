import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var fileResult: FlutterResult?
  private var exportURL: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "pennywood/files", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in
          guard let self = self else { return }
          guard self.fileResult == nil else {
            result(FlutterError(code: "busy", message: "请先完成当前文件操作", details: nil))
            return
          }
          let picker: UIDocumentPickerViewController
          switch call.method {
          case "exportBackup":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["bytes"] as? FlutterStandardTypedData else {
              result(FlutterError(code: "invalid", message: "缺少备份内容", details: nil))
              return
            }
            do {
              let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Pennywood-\(Int(Date().timeIntervalSince1970)).pennywood")
              try bytes.data.write(to: url, options: [.atomic, .completeFileProtection])
              self.exportURL = url
              picker = UIDocumentPickerViewController(url: url, in: .exportToService)
            } catch {
              result(FlutterError(code: "write", message: "备份文件写入失败，请检查本机空间", details: nil))
              return
            }
          case "importBackup":
            picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
          default:
            result(FlutterMethodNotImplemented)
            return
          }
          self.fileResult = result
          picker.delegate = self
          picker.allowsMultipleSelection = false
          picker.modalPresentationStyle = .formSheet
          var presenter: UIViewController = controller
          while let next = presenter.presentedViewController { presenter = next }
          presenter.present(picker, animated: true)
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension AppDelegate: UIDocumentPickerDelegate {
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishFile(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard exportURL == nil else {
      finishFile(true)
      return
    }
    guard let url = urls.first else {
      finishFile(nil)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size > 0 && size <= 20 * 1024 * 1024 else {
        finishFile(FlutterError(code: "size", message: "请选择不超过 20 MB 的 Pennywood 备份", details: nil))
        return
      }
      finishFile(FlutterStandardTypedData(bytes: try Data(contentsOf: url)))
    } catch {
      finishFile(FlutterError(code: "read", message: "文件读取失败，请重试；原账本保留", details: nil))
    }
  }

  private func finishFile(_ value: Any?) {
    let result = fileResult
    fileResult = nil
    if let url = exportURL { try? FileManager.default.removeItem(at: url) }
    exportURL = nil
    result?(value)
  }
}
