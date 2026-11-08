import CryptoKit
import Foundation
import Security

enum NearbyProbeFailure: Error {
  case invalid, expired, protocolViolation, storage(OSStatus)
}

struct NearbyProbeInvitation {
  let id: Data
  let secret: Data
  let expiry: Date

  static func random(_ count: Int) throws -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    let result = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    guard result == errSecSuccess else { throw NearbyProbeFailure.storage(result) }
    return Data(bytes)
  }

  static func create(now: Date) throws -> NearbyProbeInvitation {
    NearbyProbeInvitation(id: try random(16), secret: try random(32),
      expiry: Date(timeIntervalSince1970: floor(now.timeIntervalSince1970) + 120))
  }

  init(id: Data, secret: Data, expiry: Date) {
    self.id = id; self.secret = secret; self.expiry = expiry
  }

  init(payload: [UInt8], now: Date) throws {
    guard ParticleCode.valid(payload) else { throw NearbyProbeFailure.invalid }
    let seconds = payload[56..<60].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let expiry = Date(timeIntervalSince1970: Double(seconds))
    guard expiry > now, expiry.timeIntervalSince(now) <= 120 else { throw NearbyProbeFailure.expired }
    self.init(id: Data(payload[8..<24]), secret: Data(payload[24..<56]), expiry: expiry)
  }

  var payload: [UInt8] {
    var bytes = Array("PWPC".utf8) + [1, 1, 0, 0] + Array(id) + Array(secret)
    let seconds = UInt32(expiry.timeIntervalSince1970)
    bytes += [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: seconds >> $0) }
    let checksum = ParticleCode.crc(bytes)
    return bytes + [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: checksum >> $0) }
  }

  var serviceName: String { "enroll-" + id.map { String(format: "%02x", $0) }.joined() }
}

struct NearbyProbeCredential: Codable, Equatable {
  let version: Int
  let id: Data
  let secret: Data
  let primary: Bool
  var active: Bool

  func validate() throws {
    guard version == 1, id.count == 16, secret.count == 32 else { throw NearbyProbeFailure.invalid }
  }

  func serviceName(at date: Date) -> String {
    let bucket = String(Int(date.timeIntervalSince1970 / 60))
    let tag = HMAC<SHA256>.authenticationCode(for: Data(("probe-v1:" + bucket).utf8) + id,
      using: SymmetricKey(data: secret))
    return "paired-" + tag.prefix(12).map { String(format: "%02x", $0) }.joined()
  }
}

// This service never reads or deletes the production flutter_secure_storage items.
struct NearbyProbeStore {
  static let service = "pennywood.nearby.enrollment-probe.v1"
  let account: String
  init(account: String = "synthetic-pair") { self.account = account }

  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service,
     kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
  }

  func load() throws -> NearbyProbeCredential? {
    var lookup = query
    lookup[kSecReturnData as String] = true
    lookup[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let result = SecItemCopyMatching(lookup as CFDictionary, &item)
    if result == errSecItemNotFound { return nil }
    guard result == errSecSuccess else { throw NearbyProbeFailure.storage(result) }
    guard let data = item as? Data else { throw NearbyProbeFailure.invalid }
    let credential = try JSONDecoder().decode(NearbyProbeCredential.self, from: data)
    try credential.validate()
    return credential
  }

  func save(_ credential: NearbyProbeCredential) throws {
    try credential.validate()
    let data = try JSONEncoder().encode(credential)
    let attributes: [String: Any] = [kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
    var result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if result == errSecItemNotFound {
      result = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
    }
    guard result == errSecSuccess else { throw NearbyProbeFailure.storage(result) }
  }

  func forget() throws {
    let result = SecItemDelete(query as CFDictionary)
    guard result == errSecSuccess || result == errSecItemNotFound else { throw NearbyProbeFailure.storage(result) }
  }
}

struct NearbyProbeFrame: Codable {
  enum Kind: String, Codable { case hello, offer, stored, resume, resumeReceipt, activate, active, ping, pong, done, receipt }
  let version: Int
  let kind: Kind
  let nonce: String
  var credential: NearbyProbeCredential?

  init(_ kind: Kind, nonce: String, credential: NearbyProbeCredential? = nil) {
    version = 1; self.kind = kind; self.nonce = nonce; self.credential = credential
  }
}

// One small bounded frame per receive; callers never accumulate an unbounded stream.
struct NearbyProbeFraming {
  static let limit = 4096
  private var buffer = Data()

  static func encode(_ frame: NearbyProbeFrame) throws -> Data {
    let body = try JSONEncoder().encode(frame)
    guard body.count > 0, body.count <= limit else { throw NearbyProbeFailure.invalid }
    let count = UInt32(body.count)
    return Data([24, 16, 8, 0].map { UInt8(truncatingIfNeeded: count >> $0) }) + body
  }

  mutating func append(_ bytes: Data) throws -> [NearbyProbeFrame] {
    guard bytes.count <= Self.limit + 4, buffer.count + bytes.count <= 2 * (Self.limit + 4) else {
      throw NearbyProbeFailure.invalid
    }
    buffer += bytes
    var frames: [NearbyProbeFrame] = []
    while buffer.count >= 4 {
      let count = Int(buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
      guard count > 0, count <= Self.limit else { throw NearbyProbeFailure.invalid }
      guard buffer.count >= count + 4 else { break }
      let body = Data(buffer.dropFirst(4).prefix(count))
      guard let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
            Set(object.keys).isSubset(of: ["version", "kind", "nonce", "credential"]) else {
        throw NearbyProbeFailure.invalid
      }
      let frame = try JSONDecoder().decode(NearbyProbeFrame.self, from: body)
      guard frame.version == 1, UUID(uuidString: frame.nonce) != nil,
            (frame.kind == .offer) == (frame.credential != nil) else { throw NearbyProbeFailure.invalid }
      if let credential = frame.credential { try credential.validate() }
      frames.append(frame)
      buffer = Data(buffer.dropFirst(count + 4))
    }
    return frames
  }
}

final class NearbyProbeProtocol {
  enum Phase { case start, approval, offered, stored, prepared, reconnect, activating, activated, ping, pong, done, complete }
  private(set) var phase: Phase = .start
  private(set) var credential: NearbyProbeCredential?
  private(set) var nonce = UUID().uuidString
  let primary: Bool
  let enrollment: Bool
  private let persist: (NearbyProbeCredential) throws -> Void

  init(primary: Bool, enrollment: Bool, credential: NearbyProbeCredential?,
       persist: @escaping (NearbyProbeCredential) throws -> Void) {
    self.primary = primary; self.enrollment = enrollment; self.credential = credential; self.persist = persist
  }

  func begin() throws -> NearbyProbeFrame {
    guard !primary, phase == .start else { throw NearbyProbeFailure.protocolViolation }
    phase = .activating
    return NearbyProbeFrame(.hello, nonce: nonce)
  }

  func approve() throws -> NearbyProbeFrame {
    guard primary, enrollment, phase == .approval, credential == nil else { throw NearbyProbeFailure.protocolViolation }
    let pair = NearbyProbeCredential(version: 1, id: try NearbyProbeInvitation.random(16),
      secret: try NearbyProbeInvitation.random(32), primary: true, active: false)
    try persist(pair)
    credential = pair
    phase = .offered
    let offer = NearbyProbeCredential(version: 1, id: pair.id, secret: pair.secret, primary: false, active: false)
    return NearbyProbeFrame(.offer, nonce: nonce, credential: offer)
  }

  private func activateCredential() throws {
    guard var pair = credential else { throw NearbyProbeFailure.protocolViolation }
    if !pair.active {
      pair.active = true
      try persist(pair)
      credential = pair
    }
  }

  func receive(_ frame: NearbyProbeFrame) throws -> NearbyProbeFrame? {
    guard frame.version == 1, UUID(uuidString: frame.nonce) != nil,
          (frame.kind == .offer) == (frame.credential != nil) else { throw NearbyProbeFailure.invalid }
    if primary && phase == .start && frame.kind == .hello {
      nonce = frame.nonce
      if enrollment { phase = .approval; return nil }
      try activateCredential()
      phase = .activating
      return NearbyProbeFrame(.activate, nonce: nonce)
    }
    guard frame.nonce == nonce else { throw NearbyProbeFailure.protocolViolation }
    switch (primary, phase, frame.kind) {
    case (false, .activating, .offer) where enrollment && credential == nil:
      guard let pair = frame.credential, !pair.primary, !pair.active else { throw NearbyProbeFailure.invalid }
      try pair.validate()
      try persist(pair)
      credential = pair; phase = .stored
      return NearbyProbeFrame(.stored, nonce: nonce)
    case (true, .offered, .stored):
      phase = .prepared
      return NearbyProbeFrame(.resume, nonce: nonce)
    case (false, .stored, .resume) where enrollment:
      phase = .prepared
      return NearbyProbeFrame(.resumeReceipt, nonce: nonce)
    case (true, .prepared, .resumeReceipt) where enrollment:
      phase = .reconnect
      return nil
    case (false, .activating, .activate) where !enrollment:
      try activateCredential()
      phase = .activated
      return NearbyProbeFrame(.active, nonce: nonce)
    case (true, .activating, .active):
      phase = .ping
      return NearbyProbeFrame(.ping, nonce: nonce)
    case (false, .activated, .ping):
      phase = .pong
      return NearbyProbeFrame(.pong, nonce: nonce)
    case (true, .ping, .pong):
      phase = .done
      return NearbyProbeFrame(.done, nonce: nonce)
    case (false, .pong, .done):
      phase = .complete
      return NearbyProbeFrame(.receipt, nonce: nonce)
    case (true, .done, .receipt):
      phase = .complete
      return nil
    default: throw NearbyProbeFailure.protocolViolation
    }
  }
}
