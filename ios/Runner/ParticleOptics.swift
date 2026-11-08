import UIKit

struct ParticleGrayImage {
  let width: Int
  let height: Int
  let pixels: [UInt8]

  func mean(_ point: CGPoint, radius: Int) -> Double {
    let x = Int(point.x.rounded()), y = Int(point.y.rounded())
    guard x - radius >= 0, y - radius >= 0,
          x + radius < width, y + radius < height else { return 255 }
    var value = 0
    for row in (y - radius)...(y + radius) {
      for column in (x - radius)...(x + radius) { value += Int(pixels[row * width + column]) }
    }
    return Double(value) / Double((2 * radius + 1) * (2 * radius + 1))
  }

  static func fromLuma(_ source: UnsafePointer<UInt8>, width: Int, height: Int,
                       bytesPerRow: Int) -> ParticleGrayImage {
    // The camera preset bounds this to 1280 x 720. Nearest-neighbor reduction
    // can erase readable dots, so retain luma while removing row padding.
    var pixels = [UInt8](repeating: 255, count: width * height)
    pixels.withUnsafeMutableBufferPointer { destination in
      for row in 0..<height {
        destination.baseAddress!.advanced(by: row * width)
          .update(from: source.advanced(by: row * bytesPerRow), count: width)
      }
    }
    return ParticleGrayImage(width: width, height: height, pixels: pixels)
  }

  static func from(_ image: CGImage) -> ParticleGrayImage? {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 255, count: width * height)
    let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    return ok ? ParticleGrayImage(width: width, height: height, pixels: pixels) : nil
  }
}

enum ParticleOptics {
  static let anchors: [CGPoint] = [-94.0, -19, 59, 144, 221].map {
    let angle = $0 * .pi / 180
    return CGPoint(x: 260 + 210 * cos(angle), y: 260 + 210 * sin(angle))
  }
  static let sites: [[CGPoint]] = (0..<768).map { index in
    let angle = Double(index) * .pi * (3 - sqrt(5))
    let radius = 174 * sqrt((Double(index) + 0.5) / 768)
    let x = 260 + radius * cos(angle), y = 260 + radius * sin(angle)
    return [CGPoint(x: x + 2.35 * sin(angle), y: y - 2.35 * cos(angle)),
            CGPoint(x: x - 2.35 * sin(angle), y: y + 2.35 * cos(angle))]
  }
  static let paper = UIColor(red: 248/255, green: 247/255, blue: 242/255, alpha: 1)

  static func draw(in context: CGContext, rect: CGRect, payload: [UInt8]) {
    context.saveGState()
    context.setFillColor(paper.cgColor)
    context.fill(rect)
    let scale = min(rect.width, rect.height) / 520
    context.translateBy(x: rect.midX - 260 * scale, y: rect.midY - 260 * scale)
    context.scaleBy(x: scale, y: scale)
    func dot(_ point: CGPoint, _ radius: CGFloat, _ color: UIColor) {
      context.setFillColor(color.cgColor)
      context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
        width: radius * 2, height: radius * 2))
    }
    // Deterministic decoration remains outside the locator and data guard regions.
    for i in 0..<650 {
      let angle = Double(i) * 2.3999632297
      let radius = 188 + Double((i * 37) % 55)
      let point = CGPoint(x: 260 + radius * cos(angle), y: 260 + radius * sin(angle))
      if anchors.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) > 20 }) {
        dot(point, 0.8, UIColor(red: 0.77, green: 0.80, blue: 0.75, alpha: 1))
      }
    }
    let colors = [UIColor(red: 0.21, green: 0.36, blue: 0.35, alpha: 1),
                  UIColor(red: 0.25, green: 0.38, blue: 0.29, alpha: 1),
                  UIColor(red: 0.47, green: 0.32, blue: 0.23, alpha: 1)]
    let bytes = ParticleCode.encode(payload)
    for bit in 0..<768 {
      let address = (73 * bit + 19) % 768
      let value = Int((bytes[bit / 8] >> (7 - bit % 8)) & 1)
      dot(sites[address][value], 1.65, colors[(address / 9) % 3])
    }
    for (index, point) in anchors.enumerated() {
      dot(point, 4.7, UIColor(red: 0.24, green: 0.36, blue: 0.40, alpha: 1))
      for satellite in 0..<6 {
        let angle = Double(satellite) * .pi / 3 + Double(index) * 0.2
        dot(CGPoint(x: point.x + 11.8 * cos(angle), y: point.y + 11.8 * sin(angle)),
          1.35, colors[2])
      }
    }
    context.restoreGState()
  }

  private struct Blob {
    let point: CGPoint
    let area: Int
    let fillRatio: Double
    let compactness: Double
  }

  private static func locators(_ image: ParticleGrayImage) -> [CGPoint] {
    let w = image.width, h = image.height
    guard w > 0, h > 0, image.pixels.count == w * h else { return [] }
    var visited = [Bool](repeating: false, count: w * h)
    var blobs: [Blob] = []
    for start in image.pixels.indices where !visited[start] && image.pixels[start] < 145 {
      var queue = [start], cursor = 0
      visited[start] = true
      var perimeter = 0
      var sx = 0, sy = 0, xmin = w, xmax = 0, ymin = h, ymax = 0
      while cursor < queue.count {
        let at = queue[cursor]; cursor += 1
        let x = at % w, y = at / w
        sx += x; sy += y
        xmin = min(xmin, x); xmax = max(xmax, x)
        ymin = min(ymin, y); ymax = max(ymax, y)
        for next in [x > 0 ? at - 1 : -1, x + 1 < w ? at + 1 : -1,
                     y > 0 ? at - w : -1, y + 1 < h ? at + w : -1] {
          if next < 0 || image.pixels[next] >= 145 { perimeter += 1 }
          if next >= 0 && !visited[next] && image.pixels[next] < 145 {
            visited[next] = true; queue.append(next)
          }
        }
      }
      let area = queue.count
      let ratio = Double(xmax - xmin + 1) / Double(ymax - ymin + 1)
      if area >= 2 && area <= 2000 && ratio > 0.45 && ratio < 2.2 {
        blobs.append(Blob(point: CGPoint(x: Double(sx) / Double(area), y: Double(sy) / Double(area)),
          area: area, fillRatio: Double(area) / Double((xmax - xmin + 1) * (ymax - ymin + 1)),
          compactness: 4 * .pi * Double(area) / Double(perimeter * perimeter)))
      }
      // Textured backgrounds must not cause quadratic matching on an unbounded list.
      if blobs.count > 5000 { return [] }
    }
    // Locator centers are filled ellipses; screen lettering must not displace
    // them simply because a glyph has a larger connected dark area.
    let centers = blobs.filter { $0.area >= 12 && $0.fillRatio >= 0.6 }
      .sorted { $0.area > $1.area }.prefix(100)
    var candidates: [(CGPoint, Double)] = []
    for center in centers {
      let radius = sqrt(Double(center.area) / .pi)
      let count = blobs.filter { other in
        let distance = hypot(other.point.x - center.point.x, other.point.y - center.point.y)
        return other.area < center.area / 3 && distance > 1.7 * radius && distance < 3.6 * radius
      }.count
      // Small satellites can vanish after screen/camera resampling. They boost
      // ranking, but five-center geometry and the full codeword validate a fit.
      // Filled glyphs can be larger than real centers even after the fill test.
      // Penalize their irregular boundary without requiring visible satellites.
      candidates.append((center.point, Double(center.area) * pow(center.compactness, 3) *
        (1 + Double(min(count, 6)) * 0.05)))
    }
    return candidates.sorted { $0.1 > $1.1 }.prefix(8).map { $0.0 }
  }

  private static func transform(_ target: [CGPoint]) -> [Double]? {
    var rows = [[Double]]()
    for i in 0..<4 {
      let x = Double(anchors[i].x), y = Double(anchors[i].y)
      let u = Double(target[i].x), v = Double(target[i].y)
      rows.append([x, y, 1, 0, 0, 0, -u*x, -u*y, u])
      rows.append([0, 0, 0, x, y, 1, -v*x, -v*y, v])
    }
    for column in 0..<8 {
      guard let pivot = (column..<8).max(by: { abs(rows[$0][column]) < abs(rows[$1][column]) }),
            abs(rows[pivot][column]) > 1e-9 else { return nil }
      rows.swapAt(column, pivot)
      let divisor = rows[column][column]
      for j in column...8 { rows[column][j] /= divisor }
      for row in 0..<8 where row != column {
        let factor = rows[row][column]
        for j in column...8 { rows[row][j] -= factor * rows[column][j] }
      }
    }
    return rows.map { $0[8] } + [1]
  }

  private static func project(_ p: CGPoint, _ h: [Double]) -> CGPoint? {
    let x = Double(p.x), y = Double(p.y)
    let divisor = h[6]*x + h[7]*y + 1
    guard abs(divisor) > 1e-8 else { return nil }
    let u = (h[0]*x + h[1]*y + h[2]) / divisor
    let v = (h[3]*x + h[4]*y + h[5]) / divisor
    guard u.isFinite, v.isFinite, abs(u) < 10000, abs(v) < 10000 else { return nil }
    return CGPoint(x: u, y: v)
  }

  struct Sample {
    let outline: [CGPoint]
    let erasures: Int
    let minimumSeparation: Double
    let meanContrast: Double
    let fifthError: Double

    var bounds: CGRect {
      outline.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    func improves(_ other: Sample?) -> Bool {
      guard let other = other else { return true }
      return erasures < other.erasures || erasures == other.erasures && meanContrast > other.meanContrast
    }
  }

  struct Result {
    let payload: [UInt8]?
    let locatorCount: Int
    let geometryFound: Bool
    let minimumErasures: Int?
    let candidates: [CGPoint]
    let sample: Sample?
  }

  static func recognize(_ image: ParticleGrayImage) -> Result {
    let found = locators(image)
    var geometryFound = false
    var minimumErasures: Int?
    var bestSample: Sample?
    func result(_ bytes: [UInt8]? = nil) -> Result {
      Result(payload: bytes, locatorCount: found.count, geometryFound: geometryFound,
        minimumErasures: minimumErasures, candidates: found, sample: bestSample)
    }
    guard found.count >= 5 else { return result() }
    let deadline = Date.timeIntervalSinceReferenceDate + 0.3
    for a in found.indices {
      for b in found.indices where b != a {
        for c in found.indices where c != a && c != b {
          for d in found.indices where d != a && d != b && d != c {
            if Date.timeIntervalSinceReferenceDate > deadline { return result() }
            guard let h = transform([found[a], found[b], found[c], found[d]]),
                  let fifth = project(anchors[4], h),
                  found.indices.contains(where: { i in
                    i != a && i != b && i != c && i != d &&
                    hypot(found[i].x - fifth.x, found[i].y - fifth.y) < 4
                  }),
                  let center = project(CGPoint(x: 260, y: 260), h),
                  center.x > 0, center.y > 0, center.x < CGFloat(image.width), center.y < CGFloat(image.height)
            else { continue }
            geometryFound = true
            var bytes = [UInt8](repeating: 0, count: 96)
            var erasures = Set<Int>()
            var outside = false
            var minimumSeparation = Double.infinity
            var contrast = 0.0
            for bit in 0..<768 {
              let address = (73 * bit + 19) % 768
              guard let p0 = project(sites[address][0], h), let p1 = project(sites[address][1], h),
                    p0.x >= 2, p0.y >= 2, p1.x >= 2, p1.y >= 2,
                    p0.x < CGFloat(image.width - 2), p1.x < CGFloat(image.width - 2),
                    p0.y < CGFloat(image.height - 2), p1.y < CGFloat(image.height - 2)
              else { outside = true; break }
              let separation = hypot(p0.x - p1.x, p0.y - p1.y)
              let radius = separation > 5 ? 1 : 0
              let v0 = image.mean(p0, radius: radius), v1 = image.mean(p1, radius: radius)
              minimumSeparation = min(minimumSeparation, separation)
              contrast += abs(v0 - v1)
              if v1 < v0 { bytes[bit / 8] |= 1 << (7 - bit % 8) }
              if abs(v0 - v1) < 12 { erasures.insert(bit / 8) }
            }
            if !outside {
              minimumErasures = min(minimumErasures ?? 96, erasures.count)
              let outline = (0...32).compactMap { index in
                let angle = Double(index) * .pi / 16
                return project(CGPoint(x: 260 + 174 * cos(angle), y: 260 + 174 * sin(angle)), h)
              }
              let fifthError = found.indices.filter { $0 != a && $0 != b && $0 != c && $0 != d }
                .map { hypot(found[$0].x - fifth.x, found[$0].y - fifth.y) }.min() ?? .infinity
              let sample = Sample(outline: outline, erasures: erasures.count,
                minimumSeparation: minimumSeparation, meanContrast: contrast / 768, fifthError: fifthError)
              if sample.improves(bestSample) { bestSample = sample }
            }
            if !outside && erasures.count <= 32,
               let payload = ParticleCode.decode(bytes, erasures: erasures.sorted()) { return result(payload) }
            // Low contrast can mark correct samples as uncertain. Try the same
            // bits once without erasures; RS, CRC and profile checks still apply.
            if !outside && !erasures.isEmpty,
               let payload = ParticleCode.decode(bytes) { return result(payload) }
          }
        }
      }
    }
    return result()
  }
}

final class ParticlePatternView: UIView {
  var payload = ParticleCode.testPayload() { didSet { setNeedsDisplay() } }
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = ParticleOptics.paper
    isAccessibilityElement = true
    accessibilityLabel = "公开测试粒子图，请用另一台设备的栗子小镇扫描"
    contentMode = .redraw
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    ParticleOptics.draw(in: context, rect: bounds, payload: payload)
  }
}
