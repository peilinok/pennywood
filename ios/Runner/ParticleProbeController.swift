import AVFoundation
import UIKit

struct ParticleCaptureConfirmation {
  private var candidate: [UInt8]?
  private var candidateTime = 0.0
  private var latestCandidateTime = 0.0

  mutating func reset() { candidate = nil }

  mutating func observe(_ payload: [UInt8]?, at time: TimeInterval) -> Bool {
    if candidate != nil {
      if time < latestCandidateTime || time - latestCandidateTime > 1 { reset() }
      else if time - candidateTime > 1 { candidateTime = latestCandidateTime }
    }
    // Missing decodes are not disagreements. Preserve the first valid frame
    // until the accepted 100 ms...1 s confirmation window expires.
    guard let payload = payload else { return false }
    if payload == candidate {
      latestCandidateTime = time
      return time - candidateTime >= 0.1
    }
    candidate = payload
    candidateTime = time
    latestCandidateTime = time
    return false
  }
}

final class ParticleProbeController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "pennywood.particle-camera")
  private let mode = UISegmentedControl(items: ["展示配对图", "相机识别"])
  private let status = UILabel()
  private let instruction = UILabel()
  private let area = UIView()
  private let pattern = ParticlePatternView()
  private let action = UIButton(type: .system)
  private let diagnostics = UILabel()
  private let copyDiagnostics = UIButton(type: .system)
  private var preview: AVCaptureVideoPreviewLayer?
  private var cameraDevice: AVCaptureDevice?
  private var configured = false
  private var confirmation = ParticleCaptureConfirmation()
  private var lastFrame = 0.0
  private var started = 0.0
  private var visible = false
  private var runID = UUID()
  private var captureID = UUID()
  private var areaHeight: NSLayoutConstraint?
  private var processedFrames = 0
  private var locatedFrames = 0
  private var decodedFrames = 0
  private var lastDecodedTime: TimeInterval?
  private var minimumDecodedInterval: TimeInterval?
  private var minimumErasures: Int?
  private var processingMilliseconds = 0.0
  private var maximumProcessingMilliseconds = 0.0
  private var bestSample: ParticleOptics.Sample?
  private let candidateOverlay = CAShapeLayer()
  private let samplingOverlay = CAShapeLayer()
  private var overlayCandidates: [CGPoint] = []
  private var overlayOutline: [CGPoint] = []

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
    diagnostics.numberOfLines = 0
    diagnostics.font = .preferredFont(forTextStyle: .caption1)
    diagnostics.adjustsFontForContentSizeCategory = true
    diagnostics.textColor = .darkText
    copyDiagnostics.setTitle("复制诊断摘要", for: .normal)
    copyDiagnostics.titleLabel?.font = .preferredFont(forTextStyle: .body)
    copyDiagnostics.titleLabel?.adjustsFontForContentSizeCategory = true
    copyDiagnostics.titleLabel?.numberOfLines = 0
    copyDiagnostics.titleLabel?.textAlignment = .center
    copyDiagnostics.addTarget(self, action: #selector(copySummary), for: .touchUpInside)
    area.backgroundColor = ParticleOptics.paper
    area.layer.cornerRadius = 16
    area.clipsToBounds = true
    candidateOverlay.fillColor = nil
    candidateOverlay.strokeColor = UIColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1).cgColor
    candidateOverlay.lineWidth = 2
    samplingOverlay.fillColor = nil
    samplingOverlay.strokeColor = UIColor(red: 0.65, green: 0.28, blue: 0.05, alpha: 1).cgColor
    samplingOverlay.lineWidth = 2
    samplingOverlay.lineDashPattern = [6, 4]
    let stack = UIStackView(arrangedSubviews: [mode, instruction, area, status, action, diagnostics, copyDiagnostics])
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
      copyDiagnostics.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
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
    updateGeometryOverlay()
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func close() { dismiss(animated: true) }

  @objc private func copySummary() {
    UIPasteboard.general.string = diagnostics.text
    UIAccessibility.post(notification: .announcement, argument: "已复制诊断摘要")
  }

  private func stop() {
    runID = UUID()
    overlayCandidates = []
    overlayOutline = []
    updateGeometryOverlay()
    queue.async { [self] in
      if session.isRunning { session.stopRunning() }
      confirmation.reset()
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
    diagnostics.isHidden = mode.selectedSegmentIndex == 0
    copyDiagnostics.isHidden = mode.selectedSegmentIndex == 0
    diagnostics.text = "诊断：等待相机采集。"
    copyDiagnostics.isEnabled = false
    if mode.selectedSegmentIndex == 0 {
      area.addSubview(pattern)
      pattern.frame = area.bounds
      instruction.text = "用 iPhone 打开相机识别，完整拍入圆形粒子图。可将 iPad 屏幕亮度调高。"
      status.text = "公开测试图 · PWPC v1\n请保持此页，等待另一台设备扫描。"
      action.setTitle("测试图保持静止", for: .normal)
      action.isEnabled = false
    } else {
      instruction.text = "对准整个粒子图，保持稳定并避开反光。蓝色小圆环应对准定位星簇，橙色虚线圈应围住中间的数据粒子。标记仅表示几何候选。"
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
      layer.addSublayer(candidateOverlay)
      layer.addSublayer(samplingOverlay)
      preview = layer
    }
    status.text = "正在寻找完整图案……"
    diagnostics.text = "诊断：正在采集。"
    copyDiagnostics.isEnabled = false
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
          cameraDevice = camera
          configured = true
        }
        confirmation.reset()
        processedFrames = 0
        locatedFrames = 0
        decodedFrames = 0
        lastDecodedTime = nil
        minimumDecodedInterval = nil
        minimumErasures = nil
        bestSample = nil
        processingMilliseconds = 0
        maximumProcessingMilliseconds = 0
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
    let processingStarted = ProcessInfo.processInfo.systemUptime
    let w = CVPixelBufferGetWidthOfPlane(buffer, 0), h = CVPixelBufferGetHeightOfPlane(buffer, 0)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly); return
    }
    let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    let source = base.assumingMemoryBound(to: UInt8.self)
    let image = ParticleGrayImage.fromLuma(source, width: w, height: h, bytesPerRow: stride)
    CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    let result = ParticleOptics.recognize(image)
    let duration = (ProcessInfo.processInfo.systemUptime - processingStarted) * 1000
    processedFrames += 1
    if result.geometryFound { locatedFrames += 1 }
    if result.payload != nil {
      decodedFrames += 1
      if let previous = lastDecodedTime {
        minimumDecodedInterval = min(minimumDecodedInterval ?? .infinity, now - previous)
      }
      lastDecodedTime = now
    }
    if let uncertain = result.minimumErasures { minimumErasures = min(minimumErasures ?? 96, uncertain) }
    if let sample = result.sample, sample.improves(bestSample) { bestSample = sample }
    processingMilliseconds += duration
    maximumProcessingMilliseconds = max(maximumProcessingMilliseconds, duration)
    let focus = cameraDevice.map { "\($0.focusMode.rawValue)/\($0.isAdjustingFocus ? 1 : 0)/\($0.lensPosition)" } ?? "-"
    let exposure = cameraDevice.map { CMTimeGetSeconds($0.exposureDuration) * 1000 } ?? 0
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    let interval = minimumDecodedInterval.map { String(format: "%.2f 秒", $0) } ?? "-"
    let elapsed = now - started
    let stable = confirmation.observe(result.payload, at: now)
    let progress = String(format: "确认：%@ · 用时 %.1f 秒", stable ? "通过" : "等待", elapsed)
    let quality = bestSample.map {
      String(format: "最佳候选采样：数据区 %.0f×%.0f px · 最小位距 %.1f px\n平均位差 %.1f · 第五点偏差 %.1f px\n",
        $0.bounds.width, $0.bounds.height, $0.minimumSeparation, $0.meanContrast, $0.fifthError)
    } ?? "最佳候选采样：尚无完整候选。\n"
    let summary = "光学测试 build \(build) · \(w)×\(h)\n处理 \(processedFrames) 帧 · 几何候选 \(locatedFrames) 帧 · 解码 \(decodedFrames) 帧\n\(progress)\n有效解码帧最短间隔 \(interval)\n最少低置信字节 \(minimumErasures.map(String.init) ?? "-")/96\n\(quality)" +
      String(format: "处理耗时：平均 %.0f ms · 最大 %.0f ms\n对焦 mode/调整/镜头：%@ · 曝光 %.1f ms",
        processingMilliseconds / Double(processedFrames), maximumProcessingMilliseconds, focus, exposure)
    if stable { session.stopRunning() }
    let orientation = connection.videoOrientation
    let mirrored = connection.isVideoMirrored
    let size = CGSize(width: w, height: h)
    let candidates = result.candidates.map { Self.sensorPoint($0, size: size, orientation: orientation, mirrored: mirrored) }
    let outline = result.sample?.outline.map { Self.sensorPoint($0, size: size, orientation: orientation, mirrored: mirrored) } ?? []
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.visible, self.runID == id, self.mode.selectedSegmentIndex == 1,
            UIApplication.shared.applicationState == .active else { return }
      self.diagnostics.text = summary
      self.overlayCandidates = candidates
      self.overlayOutline = outline
      self.updateGeometryOverlay()
      self.copyDiagnostics.isEnabled = true
      if stable, let payload = result.payload {
        let matches = payload == ParticleCode.testPayload()
        self.status.text = matches
          ? String(format: "识别成功（光学测试）\n两次有效识别一致 · 用时 %.1f 秒\n尚未建立家庭配对或数据同步。", elapsed)
          : "识别到其他有效粒子图。此原型仅验证公开测试图，不建立配对。"
        UIAccessibility.post(notification: .announcement, argument: "粒子图识别成功")
      } else if result.payload != nil {
        self.status.text = "已读到一帧有效数据，等待第二帧确认……"
      } else {
        self.status.text = result.geometryFound
          ? "已找到几何候选，尚未读出有效数据。\n请观察小圆环和虚线圈是否对准图案。"
          : "正在寻找完整图案……\n请让整个圆形图进入画面，并调整距离。"
      }
    }
  }

  // Preview conversion expects unrotated device coordinates, even when the
  // output buffer or the visible preview has a different orientation.
  static func sensorPoint(_ point: CGPoint, size: CGSize, orientation: AVCaptureVideoOrientation,
                          mirrored: Bool) -> CGPoint {
    let x = mirrored ? 1 - point.x / size.width : point.x / size.width
    let y = point.y / size.height
    switch orientation {
    case .landscapeRight: return CGPoint(x: x, y: y)
    case .landscapeLeft: return CGPoint(x: 1 - x, y: 1 - y)
    case .portrait: return CGPoint(x: y, y: 1 - x)
    case .portraitUpsideDown: return CGPoint(x: 1 - y, y: x)
    @unknown default: return CGPoint(x: x, y: y)
    }
  }

  private func updateGeometryOverlay() {
    guard let preview = preview else { return }
    let candidates = UIBezierPath()
    for point in overlayCandidates {
      let center = preview.layerPointConverted(fromCaptureDevicePoint: point)
      candidates.append(UIBezierPath(ovalIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)))
    }
    let outline = UIBezierPath()
    for (index, point) in overlayOutline.enumerated() {
      let projected = preview.layerPointConverted(fromCaptureDevicePoint: point)
      if index == 0 { outline.move(to: projected) } else { outline.addLine(to: projected) }
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    candidateOverlay.frame = preview.bounds
    samplingOverlay.frame = preview.bounds
    candidateOverlay.path = candidates.cgPath
    samplingOverlay.path = outline.cgPath
    CATransaction.commit()
  }
}
