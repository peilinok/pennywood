import AVFoundation
import UIKit

final class ParticleProbeController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "pennywood.particle-camera")
  private let mode = UISegmentedControl(items: ["展示配对图", "相机识别"])
  private let status = UILabel()
  private let instruction = UILabel()
  private let area = UIView()
  private let pattern = ParticlePatternView()
  private let action = UIButton(type: .system)
  private var preview: AVCaptureVideoPreviewLayer?
  private var configured = false
  private var candidate: [UInt8]?
  private var candidateTime = 0.0
  private var lastFrame = 0.0
  private var started = 0.0
  private var visible = false
  private var runID = UUID()
  private var captureID = UUID()
  private var areaHeight: NSLayoutConstraint?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "粒子配对拍照验证"
    view.backgroundColor = ParticleOptics.paper
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
    mode.selectedSegmentIndex = UIDevice.current.userInterfaceIdiom == .pad ? 0 : 1
    mode.addTarget(self, action: #selector(changeMode), for: .valueChanged)
    instruction.text = "仅验证拍摄识别，不建立家庭配对。"
    instruction.numberOfLines = 0
    instruction.font = .preferredFont(forTextStyle: .body)
    instruction.adjustsFontForContentSizeCategory = true
    status.numberOfLines = 0
    status.font = .preferredFont(forTextStyle: .body)
    status.adjustsFontForContentSizeCategory = true
    status.textAlignment = .center
    action.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    action.addTarget(self, action: #selector(activate), for: .touchUpInside)
    area.backgroundColor = ParticleOptics.paper
    area.layer.cornerRadius = 16
    area.clipsToBounds = true
    let stack = UIStackView(arrangedSubviews: [mode, instruction, area, status, action])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    scroll.addSubview(stack)
    let safe = view.safeAreaLayoutGuide
    areaHeight = area.heightAnchor.constraint(equalToConstant: 300)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: safe.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
      stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
      mode.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      action.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
      areaHeight!
    ])
    instruction.setContentHuggingPriority(.required, for: .vertical)
    status.setContentHuggingPriority(.required, for: .vertical)
    action.setContentHuggingPriority(.required, for: .vertical)
    NotificationCenter.default.addObserver(self, selector: #selector(pauseCamera),
      name: UIApplication.willResignActiveNotification, object: nil)
    changeMode()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    visible = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    visible = false
    stop()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let available = view.safeAreaLayoutGuide.layoutFrame.size
    areaHeight?.constant = max(160, min(520, available.width - 32, available.height - 260))
    pattern.frame = area.bounds
    preview?.frame = area.bounds
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func close() { dismiss(animated: true) }

  private func stop() {
    runID = UUID()
    queue.async { [self] in
      if session.isRunning { session.stopRunning() }
      candidate = nil
      captureID = UUID()
    }
  }

  @objc private func pauseCamera() {
    stop()
    if mode.selectedSegmentIndex == 1 {
      status.text = "拍摄已暂停。回到此页后点击开启相机。"
      action.setTitle("开启相机", for: .normal)
    }
  }

  @objc private func changeMode() {
    stop()
    preview?.removeFromSuperlayer()
    preview = nil
    pattern.removeFromSuperview()
    if mode.selectedSegmentIndex == 0 {
      area.addSubview(pattern)
      pattern.frame = area.bounds
      instruction.text = "用 iPhone 打开相机识别，完整拍入圆形粒子图。可将 iPad 屏幕亮度调高。"
      status.text = "公开测试图 · PWPC v1\n请保持此页，等待另一台设备扫描。"
      action.setTitle("测试图保持静止", for: .normal)
      action.isEnabled = false
    } else {
      instruction.text = "对准 iPad 上的整个粒子图，让图案占画面较大区域，保持稳定并避开反光。"
      status.text = "点击开启相机。识别后显示结果与耗时。"
      action.setTitle("开启相机", for: .normal)
      action.isEnabled = true
    }
  }

  @objc private func activate() {
    guard mode.selectedSegmentIndex == 1 else { return }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: start()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        DispatchQueue.main.async {
          guard let self = self, self.visible, self.mode.selectedSegmentIndex == 1 else { return }
          if allowed { self.start() } else { self.denied() }
        }
      }
    case .denied, .restricted:
      if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
      denied()
    @unknown default: denied()
    }
  }

  private func denied() {
    status.text = "无法访问相机。请在系统设置中允许栗子小镇使用相机，再回来重试。"
    action.setTitle("打开相机权限设置", for: .normal)
  }

  private func start() {
    stop()
    let id = UUID()
    runID = id
    if preview == nil {
      let layer = AVCaptureVideoPreviewLayer(session: session)
      layer.videoGravity = .resizeAspect
      layer.frame = area.bounds
      area.layer.addSublayer(layer)
      preview = layer
    }
    status.text = "正在寻找完整图案……"
    action.setTitle("重新开始识别", for: .normal)
    queue.async { [self] in
      captureID = id
      do {
        if !configured {
          session.beginConfiguration()
          defer { session.commitConfiguration() }
          session.sessionPreset = .hd1280x720
          guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "ParticleProbe", code: 1)
          }
          let input = try AVCaptureDeviceInput(device: camera)
          guard session.canAddInput(input) else { throw NSError(domain: "ParticleProbe", code: 2) }
          session.addInput(input)
          let output = AVCaptureVideoDataOutput()
          output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
          output.alwaysDiscardsLateVideoFrames = true
          output.setSampleBufferDelegate(self, queue: queue)
          guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw NSError(domain: "ParticleProbe", code: 3)
          }
          session.addOutput(output)
          configured = true
        }
        candidate = nil
        lastFrame = 0
        started = Date.timeIntervalSinceReferenceDate
        session.startRunning()
        DispatchQueue.main.async { [weak self] in
          guard let self = self, self.runID == id else { return }
          if let connection = self.preview?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
          }
        }
      } catch {
        DispatchQueue.main.async { [weak self] in
          guard let self = self, self.runID == id else { return }
          self.status.text = "相机启动失败，请关闭此页后重试。"
        }
      }
    }
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    let now = Date.timeIntervalSinceReferenceDate
    let id = captureID
    guard now - lastFrame >= 0.15,
          let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          CVPixelBufferGetPlaneCount(buffer) >= 1 else { return }
    lastFrame = now
    let w = CVPixelBufferGetWidthOfPlane(buffer, 0), h = CVPixelBufferGetHeightOfPlane(buffer, 0)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly); return
    }
    let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    let scale = min(1.0, 960 / Double(max(w, h)))
    let width = Int(Double(w) * scale), height = Int(Double(h) * scale)
    let source = base.assumingMemoryBound(to: UInt8.self)
    var pixels = [UInt8](repeating: 255, count: width * height)
    for y in 0..<height {
      let row = Int(Double(y) / scale) * stride
      for x in 0..<width { pixels[y * width + x] = source[row + Int(Double(x) / scale)] }
    }
    CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    let result = ParticleOptics.recognize(ParticleGrayImage(width: width, height: height, pixels: pixels))
    let elapsed = now - started
    var stable = false
    if let payload = result.payload {
      if payload == candidate && now - candidateTime >= 0.1 && now - candidateTime <= 1 {
        stable = true
      } else {
        candidate = payload
        candidateTime = now
      }
    } else { candidate = nil }
    if stable { session.stopRunning() }
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.visible, self.runID == id, self.mode.selectedSegmentIndex == 1,
            UIApplication.shared.applicationState == .active else { return }
      if stable, let payload = result.payload {
        let matches = payload == ParticleCode.testPayload()
        self.status.text = matches
          ? String(format: "识别成功（光学测试）\n连续两帧一致 · 用时 %.1f 秒\n尚未建立家庭配对或数据同步。", elapsed)
          : "识别到其他有效粒子图。此原型仅验证公开测试图，不建立配对。"
        UIAccessibility.post(notification: .announcement, argument: "粒子图识别成功")
      } else {
        self.status.text = result.geometryFound
          ? "已找到定位星簇，正在校验粒子数据……\n请保持稳定、靠近一些并避开反光。"
          : "正在寻找完整图案……\n请让整个圆形图进入画面，并调整距离。"
      }
    }
  }
}
