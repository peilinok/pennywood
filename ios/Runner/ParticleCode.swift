import Foundation

// Experimental PWPC v1 transport coding; this is not an authentication mechanism.
enum ParticleCode {
  static let parityCount = 32
  private static let exponent: [Int] = {
    var result = [Int](repeating: 0, count: 510)
    var value = 1
    for index in 0..<255 {
      result[index] = value
      value <<= 1
      if value & 256 != 0 { value ^= 0x11d }
    }
    for index in 255..<510 { result[index] = result[index - 255] }
    return result
  }()
  private static let logarithm: [Int] = {
    var result = [Int](repeating: 0, count: 256)
    for index in 0..<255 { result[exponent[index]] = index }
    return result
  }()

  private static func multiply(_ a: Int, _ b: Int) -> Int {
    a == 0 || b == 0 ? 0 : exponent[logarithm[a] + logarithm[b]]
  }

  private static func divide(_ a: Int, _ b: Int) -> Int {
    precondition(b != 0)
    return a == 0 ? 0 : exponent[(logarithm[a] - logarithm[b] + 255) % 255]
  }

  private static func product(_ a: [Int], _ b: [Int]) -> [Int] {
    var result = [Int](repeating: 0, count: a.count + b.count - 1)
    for i in a.indices {
      for j in b.indices { result[i + j] ^= multiply(a[i], b[j]) }
    }
    return result
  }

  static func crc(_ bytes: [UInt8]) -> UInt32 {
    var value: UInt32 = 0xffffffff
    for byte in bytes {
      value ^= UInt32(byte)
      for _ in 0..<8 { value = (value >> 1) ^ (value & 1 == 1 ? 0xedb88320 : 0) }
    }
    return value ^ 0xffffffff
  }

  static func testPayload() -> [UInt8] {
    var bytes = Array("PWPC".utf8) + [1, 1, 0, 0] + Array(UInt8(0)..<UInt8(48))
    bytes += [0, 0, 0, 0]
    let checksum = crc(bytes)
    bytes += [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: checksum >> $0) }
    return bytes
  }

  static func valid(_ bytes: [UInt8]) -> Bool {
    guard bytes.count == 64, Array(bytes.prefix(8)) == Array("PWPC".utf8) + [1, 1, 0, 0] else {
      return false
    }
    let stored = bytes.suffix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    return crc(Array(bytes.prefix(60))) == stored
  }

  static func encode(_ bytes: [UInt8]) -> [UInt8] {
    precondition(bytes.count == 64)
    var generator = [1]
    for root in 0..<32 { generator = product(generator, [1, exponent[root]]) }
    var work = bytes.map(Int.init) + [Int](repeating: 0, count: 32)
    for i in 0..<64 {
      let factor = work[i]
      for j in 1..<generator.count { work[i + j] ^= multiply(generator[j], factor) }
    }
    return bytes + work.suffix(32).map(UInt8.init)
  }

  private static func syndromes(_ bytes: [Int]) -> [Int] {
    (0..<32).map { root in
      bytes.reduce(0) { multiply($0, exponent[root]) ^ $1 }
    }
  }

  // Ascending locator coefficients, using Berlekamp-Massey on a syndrome sequence.
  private static func locator(_ sequence: [Int]) -> [Int] {
    var current = [1], previous = [1]
    var degree = 0, shift = 1, last = 1
    for n in sequence.indices {
      var discrepancy = sequence[n]
      if degree > 0 {
        for i in 1...degree where i < current.count {
          discrepancy ^= multiply(current[i], sequence[n - i])
        }
      }
      if discrepancy == 0 { shift += 1; continue }
      let saved = current
      let scale = divide(discrepancy, last)
      if current.count < previous.count + shift {
        current += [Int](repeating: 0, count: previous.count + shift - current.count)
      }
      for i in previous.indices { current[i + shift] ^= multiply(scale, previous[i]) }
      if 2 * degree <= n {
        degree = n + 1 - degree
        previous = saved
        last = discrepancy
        shift = 1
      } else { shift += 1 }
    }
    while current.count > 1 && current.last == 0 { current.removeLast() }
    return current
  }

  static func decode(_ received: [UInt8], erasures: [Int] = []) -> [UInt8]? {
    guard received.count == 96, erasures.count <= 32,
          Set(erasures).count == erasures.count,
          erasures.allSatisfy({ (0..<96).contains($0) }) else { return nil }
    var bytes = received.map(Int.init)
    let syndrome = syndromes(bytes)
    if syndrome.allSatisfy({ $0 == 0 }) {
      let payload = Array(received.prefix(64))
      return valid(payload) ? payload : nil
    }
    var knownLocator = [1]
    for position in erasures {
      knownLocator = product(knownLocator, [1, exponent[95 - position]])
    }
    let filtered: [Int] = (erasures.count..<32).map { n in
      var value = 0
      for i in knownLocator.indices { value ^= multiply(knownLocator[i], syndrome[n - i]) }
      return value
    }
    let unknownLocator = locator(filtered)
    let errors = unknownLocator.count - 1
    guard 2 * errors + erasures.count <= 32 else { return nil }
    let combined = product(knownLocator, unknownLocator)
    let positions = (0..<96).filter { position in
      let inverse = exponent[(255 - (95 - position)) % 255]
      return combined.reversed().reduce(0) { multiply($0, inverse) ^ $1 } == 0
    }
    let count = positions.count
    guard count > 0, count == combined.count - 1, count <= 32 else { return nil }
    // Solve the syndrome Vandermonde system for error magnitudes.
    var matrix = (0..<count).map { row in
      positions.map { exponent[((95 - $0) * row) % 255] } + [syndrome[row]]
    }
    for column in 0..<count {
      guard let pivot = (column..<count).first(where: { matrix[$0][column] != 0 }) else { return nil }
      matrix.swapAt(column, pivot)
      let scale = matrix[column][column]
      for j in column...count { matrix[column][j] = divide(matrix[column][j], scale) }
      for row in 0..<count where row != column {
        let factor = matrix[row][column]
        for j in column...count { matrix[row][j] ^= multiply(factor, matrix[column][j]) }
      }
    }
    for i in positions.indices { bytes[positions[i]] ^= matrix[i][count] }
    guard syndromes(bytes).allSatisfy({ $0 == 0 }) else { return nil }
    let payload = bytes.prefix(64).map(UInt8.init)
    return valid(payload) ? payload : nil
  }
}
