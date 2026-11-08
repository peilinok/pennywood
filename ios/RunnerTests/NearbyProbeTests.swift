import Network
import Security
import UIKit
import XCTest
@testable import Runner

final class NearbyProbeTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1800000000)

  func testFreshInvitationsRoundTripAndRejectExpiryAndPublicOpticalFixture() throws {
    let first = try NearbyProbeInvitation.create(now: now)
    let second = try NearbyProbeInvitation.create(now: now)
    XCTAssertNotEqual(first.id, second.id)
    XCTAssertNotEqual(first.secret, second.secret)
    XCTAssertTrue(ParticleCode.valid(first.payload))
    let restored = try NearbyProbeInvitation(payload: first.payload, now: now)
    XCTAssertEqual(restored.id, first.id)
    XCTAssertEqual(restored.secret, first.secret)
    XCTAssertThrowsError(try NearbyProbeInvitation(payload: first.payload, now: now.addingTimeInterval(120)))
    XCTAssertThrowsError(try NearbyProbeInvitation(payload: first.payload, now: now.addingTimeInterval(-1)))
    XCTAssertThrowsError(try NearbyProbeInvitation(payload: ParticleCode.testPayload(), now: now))
    var damaged = first.payload; damaged[24] ^= 1
    XCTAssertThrowsError(try NearbyProbeInvitation(payload: damaged, now: now))
  }

  func testDynamicDisplayCarriesTheFreshInvitationInsteadOfPublicBytes() throws {
    let invitation = try NearbyProbeInvitation.create(now: now)
    let display = ParticleDisplayController(payload: invitation.payload)
    display.loadViewIfNeeded()
    display.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024)
    display.view.layoutIfNeeded()
    for child in display.view.subviews { child.layer.displayIfNeeded() }
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: display.view.bounds.size, format: format).image {
      display.view.layer.render(in: $0.cgContext)
    }
    let gray = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(rendered.cgImage)))
    XCTAssertEqual(ParticleOptics.recognize(gray).payload, invitation.payload)
  }

  func testFramingHandlesFragmentedHeaderBodyAndCoalescedFrames() throws {
    let nonce = UUID().uuidString
    let hello = try NearbyProbeFraming.encode(NearbyProbeFrame(.hello, nonce: nonce))
    let ping = try NearbyProbeFraming.encode(NearbyProbeFrame(.ping, nonce: nonce))
    var framing = NearbyProbeFraming()
    XCTAssertTrue(try framing.append(Data(hello.prefix(1))).isEmpty)
    XCTAssertTrue(try framing.append(Data(hello.dropFirst().prefix(4))).isEmpty)
    let frames = try framing.append(Data(hello.dropFirst(5)) + ping)
    XCTAssertEqual(frames.map { $0.kind }, [.hello, .ping])
    XCTAssertEqual(frames.map { $0.nonce }, [nonce, nonce])
  }

  func testFramingRejectsOversizeUnknownTypeVersionAndUnboundMessages() throws {
    for bytes in [Data([0xff, 0xff, 0xff, 0xff]), Data([0, 0, 0, 0]), Data(repeating: 1, count: 9000)] {
      var framing = NearbyProbeFraming()
      XCTAssertThrowsError(try framing.append(bytes))
    }
    let nonce = UUID().uuidString
    for object: [String: Any] in [
      ["version": 2, "kind": "hello", "nonce": nonce],
      ["version": 1, "kind": "pay", "nonce": nonce],
      ["version": 1, "kind": "hello", "nonce": "unbound"],
      ["version": 1, "kind": "hello", "nonce": nonce, "balance": 100],
      ["version": 1, "kind": "offer", "nonce": nonce]
    ] {
      let body = try JSONSerialization.data(withJSONObject: object)
      let size = UInt32(body.count)
      let bytes = Data([24, 16, 8, 0].map { UInt8(truncatingIfNeeded: size >> $0) }) + body
      var framing = NearbyProbeFraming()
      XCTAssertThrowsError(try framing.append(bytes))
    }
  }

  func testEnrollmentRequiresApprovalAndDurableInstallBeforePermanentActivation() throws {
    var hostRecord: NearbyProbeCredential?, clientRecord: NearbyProbeCredential?
    let host = NearbyProbeProtocol(primary: true, enrollment: true, credential: nil, persist: { hostRecord = $0 })
    let client = NearbyProbeProtocol(primary: false, enrollment: true, credential: nil, persist: { clientRecord = $0 })
    XCTAssertThrowsError(try host.approve())
    XCTAssertNil(try host.receive(client.begin()))
    XCTAssertEqual(host.phase, .approval)
    XCTAssertNil(hostRecord)
    XCTAssertThrowsError(try host.receive(NearbyProbeFrame(.active, nonce: host.nonce)))
    let offer = try host.approve()
    XCTAssertEqual(hostRecord?.active, false)
    let stored = try XCTUnwrap(client.receive(offer))
    XCTAssertEqual(clientRecord?.active, false)
    let resume = try XCTUnwrap(host.receive(stored))
    let receipt = try XCTUnwrap(client.receive(resume))
    XCTAssertNil(try host.receive(receipt))
    XCTAssertEqual(host.phase, .reconnect)
    XCTAssertEqual(hostRecord?.active, false, "Bootstrap transport must not activate permanent trust")
    XCTAssertEqual(clientRecord?.active, false)
    XCTAssertEqual(hostRecord?.secret, clientRecord?.secret)
    XCTAssertEqual(hostRecord?.id, clientRecord?.id)
    XCTAssertEqual(hostRecord?.primary, true)
    XCTAssertEqual(clientRecord?.primary, false)
    XCTAssertThrowsError(try host.approve(), "A consumed invitation cannot admit a second device")
    try exchange(hostRecord: &hostRecord, clientRecord: &clientRecord)
    XCTAssertEqual(hostRecord?.active, true)
    XCTAssertEqual(clientRecord?.active, true)
    let key = hostRecord?.secret
    try exchange(hostRecord: &hostRecord, clientRecord: &clientRecord)
    XCTAssertEqual(hostRecord?.secret, key, "Everyday reconnect must reuse the saved pair")
  }

  private func exchange(hostRecord: inout NearbyProbeCredential?, clientRecord: inout NearbyProbeCredential?) throws {
    var savedHost = hostRecord, savedClient = clientRecord
    let host = NearbyProbeProtocol(primary: true, enrollment: false, credential: savedHost, persist: { savedHost = $0 })
    let client = NearbyProbeProtocol(primary: false, enrollment: false, credential: savedClient, persist: { savedClient = $0 })
    var frame = try client.begin()
    var toHost = true
    for _ in 0..<8 {
      let response = try (toHost ? host : client).receive(frame)
      if let response = response { frame = response; toHost.toggle() }
      else { break }
    }
    XCTAssertEqual(host.phase, .complete)
    XCTAssertEqual(client.phase, .complete)
    hostRecord = savedHost; clientRecord = savedClient
  }

  func testRestartRecoversAllDurablePendingAndActiveCombinations() throws {
    let base = NearbyProbeCredential(version: 1, id: try NearbyProbeInvitation.random(16),
      secret: try NearbyProbeInvitation.random(32), primary: true, active: false)
    for hostActive in [false, true] {
      for clientActive in [false, true] {
        var host: NearbyProbeCredential? = NearbyProbeCredential(version: 1, id: base.id, secret: base.secret,
          primary: true, active: hostActive)
        var client: NearbyProbeCredential? = NearbyProbeCredential(version: 1, id: base.id, secret: base.secret,
          primary: false, active: clientActive)
        try exchange(hostRecord: &host, clientRecord: &client)
        XCTAssertEqual(host?.id, base.id)
        XCTAssertEqual(client?.secret, base.secret)
      }
    }
  }

  func testFailedWritesNeverAdvanceApprovalInstallOrActivation() throws {
    let host = NearbyProbeProtocol(primary: true, enrollment: true, credential: nil, persist: { _ in throw NearbyProbeFailure.storage(errSecNotAvailable) })
    let client = NearbyProbeProtocol(primary: false, enrollment: true, credential: nil, persist: { _ in throw NearbyProbeFailure.storage(errSecNotAvailable) })
    XCTAssertNil(try host.receive(client.begin()))
    XCTAssertThrowsError(try host.approve())
    XCTAssertEqual(host.phase, .approval)
    XCTAssertNil(host.credential)
    let pair = NearbyProbeCredential(version: 1, id: try NearbyProbeInvitation.random(16),
      secret: try NearbyProbeInvitation.random(32), primary: false, active: false)
    XCTAssertThrowsError(try client.receive(NearbyProbeFrame(.offer, nonce: client.nonce, credential: pair)))
    XCTAssertNil(client.credential)
    XCTAssertEqual(client.phase, .activating)
    let pending = NearbyProbeProtocol(primary: true, enrollment: false, credential: pair,
      persist: { _ in throw NearbyProbeFailure.storage(errSecNotAvailable) })
    XCTAssertThrowsError(try pending.receive(NearbyProbeFrame(.hello, nonce: UUID().uuidString)))
    XCTAssertEqual(pending.phase, .start)
    XCTAssertEqual(pending.credential?.active, false)
  }

  func testWrongNonceAndOutOfOrderFramesCannotCompleteAnExchange() throws {
    let client = NearbyProbeProtocol(primary: false, enrollment: true, credential: nil, persist: { _ in XCTFail("Unexpected write") })
    _ = try client.begin()
    XCTAssertThrowsError(try client.receive(NearbyProbeFrame(.activate, nonce: client.nonce)))
    XCTAssertThrowsError(try client.receive(NearbyProbeFrame(.done, nonce: UUID().uuidString)))
    XCTAssertNotEqual(client.phase, .complete)
  }

  func testKeychainReopenPolicyAndForgetAreIsolatedByAccount() throws {
    let first = NearbyProbeStore(account: "test-" + UUID().uuidString)
    let other = NearbyProbeStore(account: "test-" + UUID().uuidString)
    defer { try? first.forget(); try? other.forget() }
    let pair = NearbyProbeCredential(version: 1, id: try NearbyProbeInvitation.random(16),
      secret: try NearbyProbeInvitation.random(32), primary: true, active: false)
    XCTAssertNil(try first.load())
    try first.save(pair); try other.save(pair)
    XCTAssertEqual(try NearbyProbeStore(account: first.account).load(), pair)
    let lookup: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: NearbyProbeStore.service, kSecAttrAccount as String: first.account,
      kSecReturnAttributes as String: true]
    var attributes: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(lookup as CFDictionary, &attributes), errSecSuccess)
    let dictionary = try XCTUnwrap(attributes as? [String: Any])
    XCTAssertEqual(dictionary[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    XCTAssertEqual((dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue, false)
    var active = pair; active.active = true
    try first.save(active)
    XCTAssertEqual(try first.load()?.active, true)
    try first.forget()
    XCTAssertNil(try first.load())
    XCTAssertEqual(try other.load(), pair, "Forget must not delete another account")
  }

  func testDiscoveryTagsRotateAndRequireTheSameSavedPair() throws {
    let first = NearbyProbeCredential(version: 1, id: Data(repeating: 1, count: 16),
      secret: Data(repeating: 2, count: 32), primary: true, active: true)
    let second = NearbyProbeCredential(version: 1, id: first.id,
      secret: Data(repeating: 3, count: 32), primary: false, active: true)
    XCTAssertNotEqual(first.serviceName(at: now), first.serviceName(at: now.addingTimeInterval(60)))
    XCTAssertNotEqual(first.serviceName(at: now), second.serviceName(at: now))
    XCTAssertFalse(first.serviceName(at: now).contains(first.id.base64EncodedString()))
  }

  func testPolicyDenialIsDistinctFromMissingPeerAndTLSError() {
    XCTAssertTrue(NearbyProbeTransport.denied(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))))
    XCTAssertFalse(NearbyProbeTransport.denied(.dns(DNSServiceErrorType(kDNSServiceErr_NoSuchName))))
    XCTAssertFalse(NearbyProbeTransport.denied(.tls(-1)))
  }

  func testBonjourEnrollmentAndReopenedPairReconnectWithoutAnotherInvitation() throws {
    let hostStore = NearbyProbeStore(account: "test-" + UUID().uuidString)
    let clientStore = NearbyProbeStore(account: "test-" + UUID().uuidString)
    defer { try? hostStore.forget(); try? clientStore.forget() }
    let host = NearbyProbeTransport(store: hostStore)
    let client = NearbyProbeTransport(store: clientStore)
    defer { host.stop(); client.stop() }
    let enrolled = expectation(description: "Both endpoints complete permanent activation and exchange")
    enrolled.expectedFulfillmentCount = 2
    var invitationCount = 0
    var completed = 0
    var stages: [String] = []
    func record(_ event: NearbyProbeTransport.Event, side: String) {
      let label: String
      switch event {
      case .display: label = "display"
      case .approval: label = "approval"
      case .complete: label = "complete"
      case .stopped: label = "stopped"
      case .status(let message):
        if message.contains("自动寻找") { label = "browsing" }
        else if message.contains("加密连接已建立") { label = "tls-ready" }
        else if message.contains("本地网络访问受限") { label = "policy-denied" }
        else if message.contains("附近连接未完成") { label = "network-failed" }
        else if message.contains("配对图已过期") { label = "invalid-invitation" }
        else { label = "status" }
      }
      stages.append(side + "." + label)
    }
    host.onEvent = { event in
      record(event, side: "host")
      switch event {
      case .display(let invitation): invitationCount += 1; client.join(payload: invitation.payload)
      case .approval: host.approve()
      case .complete: completed += 1; enrolled.fulfill()
      default: break
      }
    }
    client.onEvent = { event in
      record(event, side: "client")
      if case .complete = event { completed += 1; enrolled.fulfill() }
    }
    host.beginEnrollment()
    wait(for: [enrolled], timeout: 20)
    XCTAssertEqual(completed, 2, "[NEARBY-STAGES] " + stages.joined(separator: ","))
    XCTAssertEqual(invitationCount, 1)
    XCTAssertEqual(try hostStore.load()?.active, true)
    XCTAssertEqual(try clientStore.load()?.active, true)
    XCTAssertTrue(host.summary.contains("首次扫码配对"))
    XCTAssertTrue(client.summary.contains("首次扫码配对"))
    let reopenedHost = NearbyProbeTransport(store: NearbyProbeStore(account: hostStore.account))
    let reopenedClient = NearbyProbeTransport(store: NearbyProbeStore(account: clientStore.account))
    defer { reopenedHost.stop(); reopenedClient.stop() }
    let synced = expectation(description: "Reopened pair authenticates with saved credentials")
    synced.expectedFulfillmentCount = 2
    for (side, transport) in [("reopened-host", reopenedHost), ("reopened-client", reopenedClient)] {
      transport.onEvent = { event in
        record(event, side: side)
        if case .display = event { XCTFail("Daily sync must not request another scan") }
        if case .approval = event { XCTFail("Saved pair must not request repeat admission") }
        if case .complete = event { synced.fulfill() }
      }
    }
    reopenedClient.sync(); reopenedHost.sync()
    wait(for: [synced], timeout: 20)
    XCTAssertTrue(reopenedHost.summary.contains("已存配对自动重连") && reopenedClient.summary.contains("已存配对自动重连"),
      "[NEARBY-STAGES] " + stages.joined(separator: ","))
    XCTAssertTrue(reopenedHost.summary.contains("已存配对自动重连"))
    XCTAssertTrue(reopenedClient.summary.contains("已存配对自动重连"))
  }

  func testRealTLSPSKNegotiationAndWrongKeyRejectionOnLoopback() throws {
    for variant in ["matching", "wrong-key", "wrong-identity"] {
      let wrongKey = variant != "matching"
      let authenticated = expectation(description: wrongKey ? "Wrong key is rejected" : "Both endpoints authenticate")
      authenticated.expectedFulfillmentCount = wrongKey ? 1 : 2
      let key = try NearbyProbeInvitation.random(32), identity = Data("synthetic-loopback-v1".utf8)
      let listener = try NWListener(using: NearbyProbeTransport.parameters(secret: key, identity: identity))
      var accepted: NWConnection?, outgoing: NWConnection?
      var rejected = false
      var receivedApplicationData = false
      defer { outgoing?.cancel(); accepted?.cancel(); listener.cancel() }
      listener.newConnectionHandler = { candidate in
        accepted = candidate
        candidate.stateUpdateHandler = { state in
          if case .ready = state {
            XCTAssertFalse(wrongKey, "Wrong PSK must never reach an authenticated ready state")
            XCTAssertTrue(NearbyProbeTransport.expectedTLS(candidate))
            authenticated.fulfill()
            candidate.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
              receivedApplicationData = !(data?.isEmpty ?? true)
            }
          }
          if case .failed = state, wrongKey, !rejected { rejected = true; authenticated.fulfill() }
        }
        candidate.start(queue: .main)
      }
      listener.stateUpdateHandler = { state in
        guard case .ready = state, let port = listener.port, outgoing == nil else { return }
        let candidate = NWConnection(host: "127.0.0.1", port: port,
          using: NearbyProbeTransport.parameters(secret: variant == "wrong-key" ? Data(repeating: 0, count: 32) : key,
            identity: variant == "wrong-identity" ? Data("another-attempt".utf8) : identity))
        outgoing = candidate
        candidate.stateUpdateHandler = { state in
          if case .ready = state {
            XCTAssertFalse(wrongKey)
            XCTAssertTrue(NearbyProbeTransport.expectedTLS(candidate))
            authenticated.fulfill()
          }
          if case .failed = state, wrongKey, !rejected { rejected = true; authenticated.fulfill() }
        }
        candidate.start(queue: .main)
      }
      listener.start(queue: .main)
      wait(for: [authenticated], timeout: 8)
      XCTAssertFalse(receivedApplicationData)
    }
  }

  func testCancelIgnoresLateDiscoveryCallbacksAndNeverPersistsAnInvitation() throws {
    let store = NearbyProbeStore(account: "test-" + UUID().uuidString)
    defer { try? store.forget() }
    let transport = NearbyProbeTransport(store: store)
    transport.beginEnrollment()
    transport.stop()
    let unexpected = expectation(description: "Cancelled enrollment cannot publish or complete later")
    unexpected.isInverted = true
    transport.onEvent = { event in
      switch event {
      case .display, .approval, .complete: unexpected.fulfill()
      default: break
      }
    }
    wait(for: [unexpected], timeout: 0.3)
    XCTAssertFalse(transport.isRunning)
    XCTAssertNil(try store.load())
  }

  func testTLSAuthenticatesMatchingIdentitiesContainingZeroAndNonUTF8Bytes() throws {
    let cases: [(String, [UInt8])] = [("zero-byte", [0, 1, 2, 3]), ("non-utf8", [0xff, 0x80, 1, 2])]
    for (label, bytes) in cases {
      let ready = expectation(description: "Both endpoints authenticate a matching " + label + " identity")
      ready.expectedFulfillmentCount = 2
      let key = try NearbyProbeInvitation.random(32)
      let identity = Data("enrollment-v1:".utf8) + Data(bytes)
      let listener = try NWListener(using: NearbyProbeTransport.parameters(secret: key, identity: identity))
      var incoming: NWConnection?, outgoing: NWConnection?
      defer { outgoing?.cancel(); incoming?.cancel(); listener.cancel() }
      listener.newConnectionHandler = { candidate in
        incoming = candidate
        candidate.stateUpdateHandler = { state in
          if case .ready = state {
            XCTAssertTrue(NearbyProbeTransport.expectedTLS(candidate))
            ready.fulfill()
          }
        }
        candidate.start(queue: .main)
      }
      listener.stateUpdateHandler = { state in
        guard case .ready = state, let port = listener.port, outgoing == nil else { return }
        let candidate = NWConnection(host: "127.0.0.1", port: port,
          using: NearbyProbeTransport.parameters(secret: key, identity: identity))
        outgoing = candidate
        candidate.stateUpdateHandler = { state in
          if case .ready = state {
            XCTAssertTrue(NearbyProbeTransport.expectedTLS(candidate))
            ready.fulfill()
          }
        }
        candidate.start(queue: .main)
      }
      listener.start(queue: .main)
      wait(for: [ready], timeout: 8)
    }
  }

  func testProbeControlsReflowAndBackgroundStopsTheSessionWithoutClearingTrust() throws {
    let store = NearbyProbeStore(account: "test-" + UUID().uuidString)
    defer { try? store.forget() }
    let pair = NearbyProbeCredential(version: 1, id: try NearbyProbeInvitation.random(16),
      secret: try NearbyProbeInvitation.random(32), primary: true, active: false)
    try store.save(pair)
    let parent = UIViewController()
    let controller = NearbyProbeController(store: store)
    parent.addChild(controller)
    parent.view.addSubview(controller.view)
    controller.didMove(toParent: parent)
    func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    let buttons = descendants(controller.view).compactMap { $0 as? UIButton }
    let sync = try XCTUnwrap(buttons.first { $0.title(for: .normal) == "同步测试消息" })
    XCTAssertTrue(sync.isEnabled, "A pending pair must offer explicit recovery")
    for size in [CGSize(width: 375, height: 812), CGSize(width: 812, height: 375),
                 CGSize(width: 768, height: 1024), CGSize(width: 375, height: 600)] {
      controller.view.frame = CGRect(origin: .zero, size: size)
      parent.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
        forChild: controller)
      controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
      for button in buttons where !button.isHidden {
        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
        XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
        XCTAssertLessThanOrEqual(button.frame.maxX, size.width)
      }
    }
    sync.sendActions(for: .touchUpInside)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    XCTAssertTrue(sync.isEnabled)
    XCTAssertEqual(try store.load(), pair, "Backgrounding must preserve prepared recovery credentials")
    let status = descendants(controller.view).compactMap { $0 as? UILabel }.first {
      $0.text == "连接已停止。已保存的测试配对保留。"
    }
    XCTAssertNotNil(status)
  }
}
