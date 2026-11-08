import Foundation
import Network
import Security

// Foreground-only synthetic probe. All mutable state is owned by the main queue.
final class NearbyProbeTransport {
  static let service = "_pw-probe._tcp"
  static let cipher = tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!
  enum Event {
    case status(String), display(NearbyProbeInvitation), approval, complete, stopped
  }
  var onEvent: ((Event) -> Void)?
  private let store: NearbyProbeStore
  private var listener: NWListener?
  private var browser: NWBrowser?
  private var connection: NWConnection?
  private var machine: NearbyProbeProtocol?
  private var invitation: NearbyProbeInvitation?
  private var credential: NearbyProbeCredential?
  private var primary = false
  private var enrollment = false
  private var beganWithScan = false
  private var consumed = false
  private var run = UUID()
  private var framing = NearbyProbeFraming()
  private var deadline: DispatchWorkItem?
  private var progressDeadline: DispatchWorkItem?
  private var advertisementTimer: Timer?
  private var started = 0.0
  private(set) var isRunning = false
  private(set) var summary = "连接测试：尚未开始。"

  init(store: NearbyProbeStore = NearbyProbeStore()) { self.store = store }

  static func parameters(secret: Data, identity: Data) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    let options = tls.securityProtocolOptions
    let key = secret.withUnsafeBytes { DispatchData(bytes: $0) }
    let identifier = identity.withUnsafeBytes { DispatchData(bytes: $0) }
    sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
    sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
    sec_protocol_options_append_tls_ciphersuite(options, cipher)
    sec_protocol_options_add_pre_shared_key(options, key as __DispatchData, identifier as __DispatchData)
    let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    parameters.includePeerToPeer = true
    return parameters
  }

  static func expectedTLS(_ connection: NWConnection) -> Bool {
    guard let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata else { return false }
    return sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata.securityProtocolMetadata) == .TLSv12 &&
      sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata.securityProtocolMetadata) == cipher
  }

  static func denied(_ error: NWError, connection: NWConnection? = nil) -> Bool {
    if case let .dns(code) = error, code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) { return true }
    if #available(iOS 14.2, *), connection?.currentPath?.unsatisfiedReason == .localNetworkDenied { return true }
    return false
  }

  private var parameters: NWParameters {
    let key = invitation?.secret ?? credential!.secret
    let id = invitation?.id ?? credential!.id
    let context = enrollment ? "enrollment-v1:" : "paired-v1:"
    return Self.parameters(secret: key, identity: Data(context.utf8) + id)
  }

  func stop() {
    isRunning = false
    run = UUID()
    deadline?.cancel(); deadline = nil
    progressDeadline?.cancel(); progressDeadline = nil
    advertisementTimer?.invalidate(); advertisementTimer = nil
    browser?.cancel(); browser = nil
    listener?.cancel(); listener = nil
    connection?.cancel(); connection = nil
    machine = nil; invitation = nil; credential = nil
    framing = NearbyProbeFraming()
    onEvent?(.stopped)
  }

  func beginEnrollment() {
    prepare()
    do {
      guard try store.load() == nil else { fail("已保存测试配对。请使用同步，或先忘记测试配对。"); return }
      primary = true; enrollment = true
      invitation = try NearbyProbeInvitation.create(now: Date())
      limitSession(seconds: 120)
      try listen()
    } catch { fail("无法创建测试邀请或保存凭据。请解锁设备后重试。") }
  }

  func join(payload: [UInt8]) {
    prepare()
    do {
      guard try store.load() == nil else { fail("已有测试配对，不能被扫描结果覆盖。"); return }
      primary = false; enrollment = true
      let parsed = try NearbyProbeInvitation(payload: payload, now: Date())
      invitation = parsed
      limitSession(seconds: min(60, parsed.expiry.timeIntervalSinceNow))
      browse()
    } catch { fail("配对图已过期或无效。请在另一台设备重新生成。") }
  }

  func sync() {
    prepare()
    do {
      guard let saved = try store.load() else { fail("尚未保存测试配对，请先完成一次扫码配对。"); return }
      credential = saved; primary = saved.primary; enrollment = false
      limitSession(seconds: 60)
      if primary { try listen() } else { browse() }
    } catch { fail("无法读取测试配对。请解锁设备后重试；未清除原有数据。") }
  }

  func approve() {
    guard let machine = machine, machine.phase == .approval,
          let invitation = invitation, invitation.expiry > Date() else {
      fail("邀请已失效，请重新开始配对。"); return
    }
    do {
      let frame = try machine.approve()
      self.invitation = nil
      deadline?.cancel(); deadline = nil
      armProgress(seconds: 30)
      onEvent?(.status("正在保存两端的测试配对……"))
      send(frame)
    } catch { fail("测试配对保存失败，尚未完成配对。请重试。") }
  }

  private func prepare() {
    stop()
    isRunning = true
    consumed = false
    beganWithScan = false
    started = ProcessInfo.processInfo.systemUptime
    summary = "连接测试：进行中。"
  }

  private func limitSession(seconds: TimeInterval) {
    let id = run
    let item = DispatchWorkItem { [weak self] in
      guard let self = self, self.run == id else { return }
      self.fail(self.enrollment ? "邀请已过期或未找到对应设备，请重新开始。" :
        "未能连接。请确认两端已打开并点击同步，Wi-Fi 已开启且允许本地网络，然后重试。")
    }
    deadline = item
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
  }

  private func armProgress(seconds: TimeInterval) {
    progressDeadline?.cancel()
    let id = run
    let item = DispatchWorkItem { [weak self] in
      guard let self = self, self.run == id else { return }
      self.fail("连接或确认超时。已保存的测试配对保留，可在两端点击同步重试。")
    }
    progressDeadline = item
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
  }

  private func listen() throws {
    let id = run
    let created = try NWListener(using: parameters)
    listener = created
    updateAdvertisement()
    created.stateUpdateHandler = { [weak self, weak created] state in
      guard let self = self, self.run == id, self.listener === created else { return }
      switch state {
      case .ready:
        if let invitation = self.invitation { self.onEvent?(.display(invitation)) }
        else { self.onEvent?(.status("等待已配对设备……\n请在另一台设备也点击同步。")) }
      case .waiting(let error), .failed(let error): self.networkFailure(error)
      default: break
      }
    }
    created.newConnectionHandler = { [weak self] candidate in
      guard let self = self, self.run == id, self.connection == nil, !self.consumed,
            self.invitation.map({ $0.expiry > Date() }) ?? true else { candidate.cancel(); return }
      self.attach(candidate)
    }
    created.start(queue: .main)
    if !enrollment {
      advertisementTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.updateAdvertisement() }
    }
    onEvent?(.status("正在开启附近设备发现……"))
  }

  private func updateAdvertisement() {
    guard let name = invitation?.serviceName ?? credential?.serviceName(at: Date()) else { return }
    listener?.service = NWListener.Service(name: name, type: Self.service)
  }

  private func browse() {
    let id = run
    let browsing = NWParameters.tcp
    browsing.includePeerToPeer = true
    let created = NWBrowser(for: .bonjour(type: Self.service, domain: nil), using: browsing)
    browser = created
    created.stateUpdateHandler = { [weak self] state in
      guard let self = self, self.run == id, self.browser === created else { return }
      switch state {
      case .waiting(let error), .failed(let error): self.networkFailure(error)
      default: break
      }
    }
    created.browseResultsChangedHandler = { [weak self] results, _ in
      guard let self = self, self.run == id, self.browser === created, self.connection == nil else { return }
      let names: Set<String>
      if let invitation = self.invitation { names = [invitation.serviceName] }
      else if let credential = self.credential {
        names = Set([-60.0, 0, 60].map { credential.serviceName(at: Date().addingTimeInterval($0)) })
      } else { return }
      guard let match = results.first(where: {
        if case let .service(name, _, _, _) = $0.endpoint { return names.contains(name) }; return false
      }) else { return }
      created.cancel(); self.browser = nil
      self.attach(NWConnection(to: match.endpoint, using: self.parameters))
    }
    created.start(queue: .main)
    onEvent?(.status("正在自动寻找对应设备……\n请保持两端 App 在前台。"))
  }

  private func attach(_ candidate: NWConnection) {
    let id = run
    connection = candidate
    framing = NearbyProbeFraming()
    machine = NearbyProbeProtocol(primary: primary, enrollment: enrollment, credential: credential,
      persist: { [store] in try store.save($0) })
    armProgress(seconds: 15)
    candidate.stateUpdateHandler = { [weak self, weak candidate] state in
      guard let self = self, let candidate = candidate, self.run == id, self.connection === candidate else { return }
      switch state {
      case .ready:
        guard Self.expectedTLS(candidate) else { self.fail("加密连接不符合预期，已停止。"); return }
        self.onEvent?(.status("加密连接已建立，正在核对测试配对……"))
        self.armProgress(seconds: 30)
        self.receive(candidate, run: id)
        if !self.primary {
          do { if let first = try self.machine?.begin() { self.send(first) } }
          catch { self.fail("配对状态无效，请重试。") }
        }
      case .waiting(let error): self.networkFailure(error)
      case .failed(let error):
        if self.primary && self.enrollment && !self.consumed && self.invitation?.expiry ?? .distantPast > Date() {
          candidate.cancel(); self.connection = nil; self.machine = nil
          self.progressDeadline?.cancel(); self.progressDeadline = nil
          self.onEvent?(.status("连接未通过认证，邀请仍有效。请用扫描的设备重试。"))
        } else { self.networkFailure(error) }
      default: break
      }
    }
    candidate.start(queue: .main)
  }

  private func receive(_ candidate: NWConnection, run id: UUID) {
    candidate.receive(minimumIncompleteLength: 1, maximumLength: NearbyProbeFraming.limit + 4) { [weak self] data, _, complete, error in
      guard let self = self, self.run == id, self.connection === candidate else { return }
      do {
        if let data = data {
          for frame in try self.framing.append(data) {
            guard let machine = self.machine else { return }
            let response = try machine.receive(frame)
            if machine.phase == .approval {
              self.consumed = true
              self.listener?.cancel(); self.listener = nil
              self.progressDeadline?.cancel(); self.progressDeadline = nil
              self.onEvent?(.approval)
            } else { self.armProgress(seconds: 30) }
            if let response = response { self.send(response) }
            else if machine.phase == .reconnect { self.resumePrepared(); return }
            else if machine.phase == .complete { self.finish(); return }
          }
        }
        if let error = error { self.networkFailure(error) }
        else if complete { self.fail("连接已中断。测试配对保留，请在两端点击同步重试。") }
        else { self.receive(candidate, run: id) }
      } catch { self.fail("收到无效数据或测试配对未能保存，已停止；不会报告同步成功。") }
    }
  }

  private func send(_ frame: NearbyProbeFrame) {
    guard let candidate = connection else { return }
    let id = run
    do {
      candidate.send(content: try NearbyProbeFraming.encode(frame), completion: .contentProcessed { [weak self] error in
        guard let self = self, self.run == id, self.connection === candidate else { return }
        if let error = error { self.networkFailure(error) }
        else if frame.kind == .resumeReceipt { self.resumePrepared() }
        else if frame.kind == .receipt { self.finish() }
      })
    } catch { fail("测试消息无法编码，已停止。") }
  }

  private func finish() {
    let elapsed = ProcessInfo.processInfo.systemUptime - started
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    summary = String(format: "连接测试 build %@\n结果：测试消息交换完成\n方式：%@\n用时：%.1f 秒\n认证：TLS 1.2 · PSK · AES-128-GCM\n测试配对：已持久化\n真实账本：未接入", build,
      beganWithScan ? "首次扫码配对" : "已存配对自动重连", elapsed)
    stop()
    onEvent?(.complete)
  }

  private func networkFailure(_ error: NWError) {
    fail(Self.denied(error, connection: connection)
      ? "本地网络访问受限。请在设置中允许栗子小镇访问本地网络，再点击重试。"
      : "附近连接未完成。请保持两端 App 打开、Wi-Fi 开启后重试。已保存的测试配对保留。")
  }

  private func resumePrepared() {
    let originalStart = started
    stop()
    isRunning = true
    started = originalStart
    beganWithScan = true
    consumed = false
    enrollment = false
    do {
      guard let saved = try store.load() else { throw NearbyProbeFailure.invalid }
      credential = saved; primary = saved.primary
      limitSession(seconds: 60)
      if primary { try listen() } else { browse() }
      onEvent?(.status("测试配对已保存，正在使用保存的凭据确认连接……"))
    } catch { fail("无法恢复待确认的测试配对，请解锁后在两端点击同步。") }
  }

  private func fail(_ message: String) {
    summary = "连接测试：未完成。\n" + message
    stop()
    onEvent?(.status(message))
  }
}
