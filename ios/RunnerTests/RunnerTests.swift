import CoreImage
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testIndependentCRCAndParityVector() {
    XCTAssertEqual(ParticleCode.crc(Array("123456789".utf8)), 0xcbf43926)
    let payload = ParticleCode.testPayload()
    XCTAssertEqual(payload.count, 64)
    XCTAssertTrue(ParticleCode.valid(payload))
    let parity = ParticleCode.encode(payload).suffix(32).map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(parity, "b7908183438d1d4f1f6353fc876857317223fdbfdd4af6e29c8e0b697e4fa0d2")
  }

  func testErrorAndErasureRecovery() {
    let payload = ParticleCode.testPayload()
    for count in [1, 8, 16] {
      var encoded = ParticleCode.encode(payload)
      for index in 0..<count { encoded[(index * 5) % 96] ^= UInt8(index + 1) }
      XCTAssertEqual(ParticleCode.decode(encoded), payload, "Unknown byte errors: \(count)")
    }
    var encoded = ParticleCode.encode(payload)
    for index in 0..<20 { encoded[index] ^= UInt8(index + 17) }
    XCTAssertEqual(ParticleCode.decode(encoded, erasures: Array(0..<20)), payload)
    encoded = ParticleCode.encode(payload)
    for index in 0..<18 { encoded[index] ^= UInt8(index + 11) }
    XCTAssertEqual(ParticleCode.decode(encoded, erasures: Array(0..<12)), payload)
  }

  func testDamagedAndUnsupportedPayloadsAreRejected() {
    XCTAssertNil(ParticleCode.decode([0]))
    let payload = ParticleCode.testPayload()
    XCTAssertNil(ParticleCode.decode(ParticleCode.encode(payload), erasures: [-1]))
    var wrong = payload
    wrong[10] ^= 1
    XCTAssertNil(ParticleCode.decode(ParticleCode.encode(wrong)))
    wrong = payload
    wrong[4] = 2
    XCTAssertNil(ParticleCode.decode(ParticleCode.encode(wrong)))
    var damaged = ParticleCode.encode(payload)
    for index in 0..<40 { damaged[index] ^= UInt8(index + 1) }
    XCTAssertNil(ParticleCode.decode(damaged))
  }

  func testRenderedParticlesDecodeAcrossRotationMirrorAndScale() throws {
    let payload = ParticleCode.testPayload()
    for (angle, mirror, scale) in [(0.0, false, 1.0), (0.31, false, 0.9), (0.0, true, 0.85)] {
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let image = UIGraphicsImageRenderer(size: CGSize(width: 700, height: 700), format: format).image { renderer in
        let context = renderer.cgContext
        context.setFillColor(ParticleOptics.paper.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 700, height: 700))
        context.translateBy(x: 350, y: 350)
        context.rotate(by: angle)
        context.scaleBy(x: mirror ? -scale : scale, y: scale)
        ParticleOptics.draw(in: context, rect: CGRect(x: -260, y: -260, width: 520, height: 520), payload: payload)
      }
      let gray = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(image.cgImage)))
      let result = ParticleOptics.recognize(gray)
      XCTAssertEqual(result.payload, payload, "angle=\(angle), mirror=\(mirror), locators=\(result.locatorCount)")
    }
  }

  func testBlankAndUnrelatedImagesAreRejected() {
    let blank = ParticleGrayImage(width: 520, height: 520, pixels: [UInt8](repeating: 248, count: 520 * 520))
    XCTAssertNil(ParticleOptics.recognize(blank).payload)
    var pixels = blank.pixels
    for i in 0..<1000 {
      let x = (i * 73 + 19) % 516, y = (i * 137 + 7) % 516
      for dy in 0..<4 { for dx in 0..<4 { pixels[(y + dy) * 520 + x + dx] = 70 } }
    }
    XCTAssertNil(ParticleOptics.recognize(ParticleGrayImage(width: 520, height: 520, pixels: pixels)).payload)
  }

  func testPerspectiveAndMildBlurDecode() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: 520, height: 520), format: format).image { renderer in
      ParticleOptics.draw(in: renderer.cgContext, rect: CGRect(x: 0, y: 0, width: 520, height: 520),
        payload: ParticleCode.testPayload())
    }
    let source = CIImage(cgImage: try XCTUnwrap(rendered.cgImage))
    let filter = try XCTUnwrap(CIFilter(name: "CIPerspectiveTransform", parameters: [
      kCIInputImageKey: source,
      "inputTopLeft": CIVector(x: 55, y: 565), "inputTopRight": CIVector(x: 550, y: 530),
      "inputBottomRight": CIVector(x: 525, y: 45), "inputBottomLeft": CIVector(x: 30, y: 90)
    ]))
    let context = CIContext()
    let warped = try XCTUnwrap(filter.outputImage)
    let background = CIImage(color: CIColor(red: 248/255, green: 247/255, blue: 242/255))
    let composed = warped.composited(over: background).cropped(to: CGRect(x: 0, y: 0, width: 600, height: 600))
    let blur = try XCTUnwrap(CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: composed, kCIInputRadiusKey: 0.45]))
    let pixels = try XCTUnwrap(context.createCGImage(try XCTUnwrap(blur.outputImage), from: composed.extent))
    let gray = try XCTUnwrap(ParticleGrayImage.from(pixels))
    let result = ParticleOptics.recognize(gray)
    let attachment = XCTAttachment(image: UIImage(cgImage: pixels))
    attachment.name = "synthetic-perspective"
    attachment.lifetime = .keepAlways
    add(attachment)
    let provider = try XCTUnwrap(CGDataProvider(data: Data(gray.pixels) as CFData))
    let grayCG = try XCTUnwrap(CGImage(width: gray.width, height: gray.height, bitsPerComponent: 8,
      bitsPerPixel: 8, bytesPerRow: gray.width, space: CGColorSpaceCreateDeviceGray(),
      bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let grayAttachment = XCTAttachment(image: UIImage(cgImage: grayCG))
    grayAttachment.name = "synthetic-grayscale"
    grayAttachment.lifetime = .keepAlways
    add(grayAttachment)
    XCTAssertEqual(result.payload, ParticleCode.testPayload(), "locators=\(result.locatorCount), min=\(gray.pixels.min()!), dark=\(gray.pixels.filter { $0 < 145 }.count)")
  }
}
