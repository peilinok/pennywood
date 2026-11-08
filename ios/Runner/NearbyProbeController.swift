import UIKit

final class NearbyProbeController: UIViewController {
  private let store: NearbyProbeStore
  private let transport: NearbyProbeTransport
  private let status = UILabel()
  private let pairing = UILabel()
  private let create = UIButton(type: .system)
  private let scan = UIButton(type: .system)
  private let sync = UIButton(type: .system)
  private let approve = UIButton(type: .system)
  private let cancel = UIButton(type: .system)
  private let forget = UIButton(type: .system)
  private var display: ParticleDisplayController?

  init(store: NearbyProbeStore = NearbyProbeStore()) {
    self.store = store
    transport = NearbyProbeTransport(store: store)
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "附近连接验证"
    overrideUserInterfaceStyle = .light
    view.backgroundColor = ParticleOptics.paper
    isModalInPresentation = true
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
    let instruction = UILabel()
    instruction.text = "首次：一端展示粒子图，另一端扫描，由展示端确认接纳。\n以后：两端点击同步，自动连接。\n仅交换测试消息，尚未接入家庭账本。"
    for label in [instruction, status, pairing] {
      label.font = .preferredFont(forTextStyle: .body)
      label.adjustsFontForContentSizeCategory = true
      label.numberOfLines = 0
      label.textColor = .label
    }
    let settings = UIButton(type: .system)
    let copy = UIButton(type: .system)
    let rows: [(UIButton, String, Selector)] = [
      (create, "展示临时配对图", #selector(startEnrollment)),
      (scan, "扫描并配对", #selector(startScan)),
      (approve, "确认接纳这台测试设备", #selector(confirm)),
      (sync, "同步测试消息", #selector(startSync)),
      (cancel, "取消本次连接", #selector(stop)),
      (forget, "忘记测试配对", #selector(forgetPair)),
      (settings, "打开权限设置", #selector(openSettings)),
      (copy, "复制连接诊断", #selector(copySummary))
    ]
    for (button, text, selector) in rows {
      button.setTitle(text, for: .normal)
      button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
      button.titleLabel?.adjustsFontForContentSizeCategory = true
      button.titleLabel?.numberOfLines = 0
      button.titleLabel?.textAlignment = .center
      button.addTarget(self, action: selector, for: .touchUpInside)
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }
    let stack = UIStackView(arrangedSubviews: [instruction, pairing, status] + rows.map { $0.0 })
    stack.axis = .vertical; stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll); scroll.addSubview(stack)
    let safe = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: safe.topAnchor), scroll.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: safe.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
      stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
    ])
    transport.onEvent = { [weak self] in self?.handle($0) }
    NotificationCenter.default.addObserver(self, selector: #selector(background),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    status.text = "等待开始。请保持两端 App 打开，Wi-Fi 开启。"
    setBusy(false)
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  private func setBusy(_ busy: Bool) {
    approve.isHidden = true
    cancel.isHidden = !busy
    do {
      let saved = try store.load()
      create.isEnabled = !busy && saved == nil
      scan.isEnabled = !busy && saved == nil
      sync.isEnabled = !busy && saved != nil
      forget.isEnabled = !busy && saved != nil
      pairing.text = saved.map {
        "测试配对：\($0.active ? "已保存" : "待恢复确认") · \($0.primary ? "展示端" : "扫描端")"
      } ?? "测试配对：尚未建立"
    } catch {
      create.isEnabled = false; scan.isEnabled = false; sync.isEnabled = false; forget.isEnabled = false
      pairing.text = "测试配对读取失败。请解锁设备后重新打开此页。"
    }
  }

  private func hideDisplay() {
    if let display = display { display.dismiss(animated: false); self.display = nil }
  }

  private func handle(_ event: NearbyProbeTransport.Event) {
    switch event {
    case .stopped: hideDisplay(); setBusy(false)
    case .status(let message):
      setBusy(transport.isRunning)
      status.text = message
      UIAccessibility.post(notification: .announcement, argument: message)
    case .display(let invitation):
      setBusy(true)
      let screen = ParticleDisplayController(payload: invitation.payload)
      screen.modalPresentationStyle = .fullScreen
      screen.onClose = { [weak self] in self?.display = nil; self?.stop() }
      display = screen
      present(screen, animated: !UIAccessibility.isReduceMotionEnabled)
    case .approval:
      hideDisplay()
      status.text = "粒子图已识别，加密连接已建立。确认后才保存测试配对。"
      approve.isHidden = false
      UIAccessibility.post(notification: .layoutChanged, argument: approve)
    case .complete:
      status.text = "测试消息交换完成。\n下一次只需两端点击「同步测试消息」。真实账本尚未接入。"
      UIAccessibility.post(notification: .layoutChanged, argument: status)
    }
  }

  @objc private func startEnrollment() { transport.beginEnrollment(); setBusy(transport.isRunning) }
  @objc private func startSync() { transport.sync(); setBusy(transport.isRunning) }
  @objc private func confirm() { approve.isHidden = true; transport.approve() }

  @objc private func startScan() {
    let scanner = ParticleProbeController()
    scanner.onPayload = { [weak self, weak scanner] payload in
      scanner?.dismiss(animated: false) {
        guard let self = self, UIApplication.shared.applicationState == .active else { return }
        self.transport.join(payload: payload)
        self.setBusy(self.transport.isRunning)
      }
    }
    let navigation = UINavigationController(rootViewController: scanner)
    navigation.modalPresentationStyle = .fullScreen
    present(navigation, animated: !UIAccessibility.isReduceMotionEnabled)
  }

  @objc private func stop() { transport.stop(); status.text = "连接已停止。已保存的测试配对保留。" }
  @objc private func close() { transport.stop(); dismiss(animated: !UIAccessibility.isReduceMotionEnabled) }
  @objc private func background() { stop() }
  @objc private func openSettings() {
    stop()
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
  }
  @objc private func copySummary() {
    UIPasteboard.general.string = transport.summary
    UIAccessibility.post(notification: .announcement, argument: "已复制连接诊断")
  }
  @objc private func forgetPair() {
    let alert = UIAlertController(title: "忘记测试配对？", message: "仅清除本机的测试连接凭据。再次测试需两端都忘记后重新扫码。", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
    alert.addAction(UIAlertAction(title: "忘记", style: .destructive) { [weak self] _ in
      guard let self = self else { return }
      do { try self.store.forget(); self.setBusy(false); self.status.text = "本机测试配对已清除。" }
      catch { self.status.text = "清除失败，测试配对仍保留。" }
    })
    present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
  }
}
