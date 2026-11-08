import AVFoundation
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

  func testScreenCaptionDoesNotHideParticleLocators() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let payload = ParticleCode.testPayload()
    let image = UIGraphicsImageRenderer(size: CGSize(width: 960, height: 540), format: format).image { renderer in
      renderer.cgContext.setFillColor(ParticleOptics.paper.cgColor)
      renderer.cgContext.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
      ParticleOptics.draw(in: renderer.cgContext,
        rect: CGRect(x: 310, y: 100, width: 340, height: 340), payload: payload)
      ("公开测试图" as NSString).draw(at: CGPoint(x: 120, y: 10),
        withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.darkGray])
    }
    let gray = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(image.cgImage)))
    let result = ParticleOptics.recognize(gray)
    XCTAssertEqual(result.payload, payload, "Screen caption must not displace locator candidates: \(result.locatorCount)")
  }

  func testDisplayTextCannotDisplaceRealLocatorConstellations() throws {
    let captions = [
      ("用 iPhone 打开相机识别，完整拍入圆形粒子图。可将 iPad 屏幕亮度调高。", CGRect(x: 16, y: 72, width: 736, height: 20.33333333333333)),
      ("公开测试图 · PWPC v1\n请保持此页，等待另一台设备扫描。", CGRect(x: 16, y: 644.3333333333334, width: 736, height: 42.33333333333337)),
      ("展示配对图", CGRect(x: 167.33333333333334, y: 26.666666666666668, width: 64.66666666666666, height: 15.666666666666668)),
      ("相机识别", CGRect(x: 542.3333333333334, y: 26.666666666666668, width: 51.66666666666663, height: 15.666666666666668))
    ]
    for angle in [0.0, Double.pi / 2] {
      let clear = ParticleOptics.recognize(try displayCaptionFrame(captions: [], angle: angle))
      XCTAssertEqual(clear.payload, ParticleCode.testPayload(), "The same field is readable without text")
      XCTAssertEqual(clear.candidates.count, 5)
      for visibleCaptions in [[captions[0]], [captions[1]], captions] {
        let result = ParticleOptics.recognize(try displayCaptionFrame(captions: visibleCaptions, angle: angle))
        XCTAssertEqual(result.payload, ParticleCode.testPayload(), "Display text must not hide a readable field at angle \(angle)")
        for locator in clear.candidates {
          XCTAssertTrue(result.candidates.contains { hypot($0.x - locator.x, $0.y - locator.y) < 2 },
            "All five real locator centers must survive candidate ranking")
        }
      }
    }
  }

  private func displayCaptionFrame(captions: [(String, CGRect)], angle: Double) throws -> ParticleGrayImage {
    let screen = UIView(frame: CGRect(x: 0, y: 0, width: 768, height: 1024))
    screen.backgroundColor = ParticleOptics.paper
    let pattern = ParticlePatternView(frame: CGRect(x: 16, y: 108.33333333333331, width: 736, height: 520))
    screen.addSubview(pattern)
    for caption in captions {
      let label = UILabel(frame: caption.1)
      label.text = caption.0
      label.font = .systemFont(ofSize: caption.1.minY < 50 ? 13 : 17)
      label.textColor = .black
      label.numberOfLines = 0
      label.textAlignment = caption.1.minY > 600 ? .center : .left
      screen.addSubview(label)
    }
    screen.layoutIfNeeded()
    pattern.layer.displayIfNeeded()
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: screen.bounds.size, format: format).image {
      screen.layer.render(in: $0.cgContext)
    }
    let captured = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720), format: format).image { renderer in
      let context = renderer.cgContext
      context.setFillColor(ParticleOptics.paper.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
      context.translateBy(x: 640, y: 360)
      context.rotate(by: angle)
      context.scaleBy(x: 400.0 / 520, y: 400.0 / 520)
      rendered.draw(at: CGPoint(x: -384, y: -368.3333333333333))
    }
    let input = CIImage(cgImage: try XCTUnwrap(captured.cgImage))
    let blurred = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6]).cropped(to: input.extent)
    return try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(CIContext().createCGImage(blurred, from: input.extent))))
  }

  func testCleanDisplayRemainsReadableAcrossReflowAndAppearance() throws {
    let display = ParticleDisplayController()
    display.loadViewIfNeeded()
    let pattern = try XCTUnwrap(descendants(display.view).compactMap { $0 as? ParticlePatternView }.first)
    let close = try XCTUnwrap(descendants(display.view).compactMap { $0 as? UIButton }.first)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    for style in [UIUserInterfaceStyle.light, .dark] {
      display.overrideUserInterfaceStyle = style
      for size in [CGSize(width: 375, height: 812), CGSize(width: 812, height: 375),
                   CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768),
                   CGSize(width: 375, height: 600)] {
        display.view.frame = CGRect(origin: .zero, size: size)
        display.view.setNeedsLayout()
        display.view.layoutIfNeeded()
        pattern.layer.displayIfNeeded()
        let image = UIGraphicsImageRenderer(size: size, format: format).image {
          display.view.layer.render(in: $0.cgContext)
        }
        let result = ParticleOptics.recognize(try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(image.cgImage))))
        XCTAssertEqual(result.payload, ParticleCode.testPayload(), "Clean display must remain readable at \(size), style \(style)")
        XCTAssertFalse(pattern.frame.intersects(close.frame))
        XCTAssertTrue(display.view.safeAreaLayoutGuide.layoutFrame.contains(close.frame))
        XCTAssertGreaterThanOrEqual(close.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(close.bounds.height, 44)
        XCTAssertEqual(close.accessibilityLabel, "退出全屏展示")
        XCTAssertFalse(descendants(display.view).compactMap { $0 as? UILabel }.contains {
          !$0.isHidden && !($0.text ?? "").isEmpty
        }, "Only the particle field and exit icon may be visible")
      }
    }
  }

  func testFullScreenDisplayOpensAndReturnsToProbeControls() throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let previous = scene.windows.first { $0.isKeyWindow }
    let window = UIWindow(windowScene: scene)
    let probe = ParticleProbeController()
    let navigation = UINavigationController(rootViewController: probe)
    let animations = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    defer {
      window.isHidden = true
      window.rootViewController = nil
      previous?.makeKey()
      UIView.setAnimationsEnabled(animations)
    }
    window.rootViewController = navigation
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    let mode = try XCTUnwrap(descendants(probe.view).compactMap { $0 as? UISegmentedControl }.first)
    mode.selectedSegmentIndex = 0
    mode.sendActions(for: .valueChanged)
    let open = try XCTUnwrap(descendants(probe.view).compactMap { $0 as? UIButton }.first {
      $0.title(for: .normal) == "全屏展示配对图"
    })
    XCTAssertTrue(open.isEnabled)
    open.sendActions(for: .touchUpInside)
    let presented = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      probe.presentedViewController != nil && probe.presentedViewController?.isBeingPresented == false
    }, object: nil)
    wait(for: [presented], timeout: 2)
    let display = try XCTUnwrap(probe.presentedViewController as? ParticleDisplayController)
    XCTAssertEqual(display.modalPresentationStyle, .fullScreen)
    let close = try XCTUnwrap(descendants(display.view).compactMap { $0 as? UIButton }.first)
    close.sendActions(for: .touchUpInside)
    let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      probe.presentedViewController == nil
    }, object: nil)
    wait(for: [dismissed], timeout: 2)
    XCTAssertNil(probe.presentedViewController)
    XCTAssertEqual(mode.selectedSegmentIndex, 0)
    XCTAssertTrue(open.isEnabled)
    XCTAssertTrue(navigation.topViewController === probe)
  }

  private func descendants(_ view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }

  func testGeometryFeedbackDistinguishesTextFromDamagedCode() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    for hasPattern in [false, true] {
      var damaged = ParticleCode.testPayload()
      damaged[10] ^= 1
      let image = UIGraphicsImageRenderer(size: CGSize(width: 960, height: 540), format: format).image { renderer in
        renderer.cgContext.setFillColor(ParticleOptics.paper.cgColor)
        renderer.cgContext.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
        if hasPattern {
          ParticleOptics.draw(in: renderer.cgContext,
            rect: CGRect(x: 310, y: 100, width: 340, height: 340), payload: damaged)
        }
        ("公开测试图" as NSString).draw(at: CGPoint(x: 120, y: 10),
          withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.darkGray])
      }
      let gray = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(image.cgImage)))
      let result = ParticleOptics.recognize(gray)
      XCTAssertNil(result.payload)
      XCTAssertEqual(result.geometryFound, hasPattern)
    }
  }

  func testCameraLumaCopyPreservesDecodableBlurredParticles() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    for (width, blur) in [(400.0, 1.2), (460.0, 1.6)] {
      let image = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720), format: format).image { renderer in
        renderer.cgContext.setFillColor(ParticleOptics.paper.cgColor)
        renderer.cgContext.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
        ParticleOptics.draw(in: renderer.cgContext,
          rect: CGRect(x: 640 - width / 2 + 0.3, y: 360 - width / 2 + 0.6, width: width, height: width),
          payload: ParticleCode.testPayload())
      }
      let input = CIImage(cgImage: try XCTUnwrap(image.cgImage))
      let softened = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur]).cropped(to: input.extent)
      let raw = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(CIContext().createCGImage(softened, from: input.extent))))
      XCTAssertEqual(ParticleOptics.recognize(raw).payload, ParticleCode.testPayload(), "Source frame is readable")
      let stride = 1344
      var storage = [UInt8](repeating: 0, count: stride * 720)
      for row in 0..<720 {
        storage.replaceSubrange((row * stride)..<(row * stride + 1280),
          with: raw.pixels[(row * 1280)..<((row + 1) * 1280)])
      }
      let captured = storage.withUnsafeBufferPointer {
        ParticleGrayImage.fromLuma($0.baseAddress!, width: 1280, height: 720, bytesPerRow: stride)
      }
      XCTAssertEqual(ParticleOptics.recognize(captured).payload, ParticleCode.testPayload(),
        "Camera conversion must retain readable particles at width \(width), blur \(blur)")
    }
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

  func testLowContrastBlurredSamplesDecodeWithoutDiscardingCorrectBits() throws {
    for (width, blur) in [(300.0, 1.4), (400.0, 1.8)] {
      let gray = try lowContrastParticles(width: width, blur: blur, payload: ParticleCode.testPayload())
      let result = ParticleOptics.recognize(gray)
      XCTAssertTrue(result.geometryFound)
      XCTAssertGreaterThan(try XCTUnwrap(result.minimumErasures), 32,
        "The fixture must exercise uncertain samples beyond the erasure bound")
      XCTAssertEqual(result.payload, ParticleCode.testPayload(),
        "Readable low-contrast samples must reach full decoding: width=\(width), blur=\(blur)")
    }
  }

  func testLowContrastFallbackValidatesPayloadInsteadOfAssumingTestPattern() throws {
    var other = ParticleCode.testPayload()
    other[8] ^= 0x59
    let checksum = ParticleCode.crc(Array(other.prefix(60)))
    other.replaceSubrange(60..<64, with: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: checksum >> $0) })
    XCTAssertTrue(ParticleCode.valid(other))
    XCTAssertEqual(ParticleOptics.recognize(try lowContrastParticles(width: 400, blur: 1.8, payload: other)).payload, other)
    other[10] ^= 1
    XCTAssertNil(ParticleOptics.recognize(try lowContrastParticles(width: 400, blur: 1.8, payload: other)).payload,
      "A fully RS-encoded image with an invalid CRC must still fail")
    other = ParticleCode.testPayload()
    other[5] = 2
    let unsupportedCRC = ParticleCode.crc(Array(other.prefix(60)))
    other.replaceSubrange(60..<64, with: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: unsupportedCRC >> $0) })
    XCTAssertNil(ParticleOptics.recognize(try lowContrastParticles(width: 400, blur: 1.8, payload: other)).payload,
      "A valid CRC cannot authorize an unsupported optical profile")
  }

  private func lowContrastParticles(width: Double, blur: Double, payload: [UInt8]) throws -> ParticleGrayImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720), format: format).image { renderer in
      renderer.cgContext.setFillColor(ParticleOptics.paper.cgColor)
      renderer.cgContext.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
      ParticleOptics.draw(in: renderer.cgContext,
        rect: CGRect(x: 640 - width / 2 + 0.3, y: 360 - width / 2 + 0.6, width: width, height: width), payload: payload)
    }
    let input = CIImage(cgImage: try XCTUnwrap(rendered.cgImage))
    let softened = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur]).cropped(to: input.extent)
    let raw = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(CIContext().createCGImage(softened, from: input.extent))))
    return ParticleGrayImage(width: raw.width, height: raw.height,
      pixels: raw.pixels.map { UInt8(90 + (Double($0) - 90) * 0.6) })
  }

  func testMatchingDecodedFramesConfirmAcrossUndecodableFrames() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 520, height: 520), format: format).image { renderer in
      ParticleOptics.draw(in: renderer.cgContext, rect: CGRect(x: 0, y: 0, width: 520, height: 520),
        payload: ParticleCode.testPayload())
    }
    let gray = try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(image.cgImage)))
    let decoded = try XCTUnwrap(ParticleOptics.recognize(gray).payload)
    let blank = ParticleGrayImage(width: 520, height: 520, pixels: [UInt8](repeating: 248, count: 520 * 520))
    let missing = ParticleOptics.recognize(blank).payload
    XCTAssertNil(missing)
    var confirmation = ParticleCaptureConfirmation()
    XCTAssertFalse(confirmation.observe(decoded, at: 0))
    XCTAssertFalse(confirmation.observe(missing, at: 0.15))
    XCTAssertFalse(confirmation.observe(missing, at: 0.30))
    XCTAssertTrue(confirmation.observe(decoded, at: 0.45), "A missed frame must not discard a valid in-window candidate")
  }

  func testSamplingDiagnosticsLocateTheRenderedDataField() throws {
    let result = ParticleOptics.recognize(try samplingFrame(includeData: true))
    XCTAssertEqual(result.payload, ParticleCode.testPayload())
    let sample = try XCTUnwrap(result.sample)
    let bounds = sample.outline.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
    XCTAssertEqual(bounds.minX, 466, accuracy: 2)
    XCTAssertEqual(bounds.maxX, 814, accuracy: 2)
    XCTAssertEqual(bounds.minY, 186, accuracy: 2)
    XCTAssertEqual(bounds.maxY, 534, accuracy: 2)
    XCTAssertEqual(sample.minimumSeparation, 4.7, accuracy: 0.1)
    XCTAssertGreaterThan(sample.meanContrast, 40)
    XCTAssertLessThan(sample.fifthError, 4)
    XCTAssertEqual(sample.erasures, result.minimumErasures)
    XCTAssertTrue((5...8).contains(result.candidates.count))
  }

  func testLocatorOnlyAndBlankFramesDoNotReportReadableData() throws {
    let result = ParticleOptics.recognize(try samplingFrame(includeData: false))
    XCTAssertTrue(result.geometryFound, "Five real locator centers can match without data")
    XCTAssertNil(result.payload)
    let sample = try XCTUnwrap(result.sample)
    XCTAssertEqual(sample.erasures, 96)
    XCTAssertEqual(sample.meanContrast, 0, accuracy: 0.1)
    let blank = ParticleGrayImage(width: 1280, height: 720,
      pixels: [UInt8](repeating: 248, count: 1280 * 720))
    let cleared = ParticleOptics.recognize(blank)
    XCTAssertNil(cleared.sample)
    XCTAssertTrue(cleared.candidates.isEmpty)
    XCTAssertFalse(cleared.geometryFound)
  }

  func testPreviewCoordinatesPreserveSensorLocationAcrossBufferOrientations() {
    let frames: [(AVCaptureVideoOrientation, CGSize, CGPoint)] = [
      (.landscapeRight, CGSize(width: 1280, height: 720), CGPoint(x: 256, y: 504)),
      (.landscapeLeft, CGSize(width: 1280, height: 720), CGPoint(x: 1024, y: 216)),
      (.portrait, CGSize(width: 720, height: 1280), CGPoint(x: 216, y: 256)),
      (.portraitUpsideDown, CGSize(width: 720, height: 1280), CGPoint(x: 504, y: 1024))
    ]
    for (orientation, size, point) in frames {
      for mirrored in [false, true] {
        let input = CGPoint(x: mirrored ? size.width - point.x : point.x, y: point.y)
        let sensor = ParticleProbeController.sensorPoint(input, size: size, orientation: orientation, mirrored: mirrored)
        XCTAssertEqual(sensor.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(sensor.y, 0.7, accuracy: 0.0001)
      }
    }
  }

  private func samplingFrame(includeData: Bool) throws -> ParticleGrayImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720), format: format).image { renderer in
      let context = renderer.cgContext
      context.setFillColor(ParticleOptics.paper.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
      if includeData {
        ParticleOptics.draw(in: context, rect: CGRect(x: 380, y: 100, width: 520, height: 520),
          payload: ParticleCode.testPayload())
      } else {
        context.setFillColor(UIColor.darkGray.cgColor)
        for point in ParticleOptics.anchors {
          context.fillEllipse(in: CGRect(x: 380 + point.x - 4.7, y: 100 + point.y - 4.7, width: 9.4, height: 9.4))
        }
      }
    }
    return try XCTUnwrap(ParticleGrayImage.from(try XCTUnwrap(rendered.cgImage)))
  }

  func testConfirmationRetainsFirstFrameUntilMinimumSeparation() {
    var confirmation = ParticleCaptureConfirmation()
    let payload = ParticleCode.testPayload()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertFalse(confirmation.observe(payload, at: 0), "The same acquisition time cannot confirm")
    XCTAssertFalse(confirmation.observe(payload, at: 0.05))
    XCTAssertTrue(confirmation.observe(payload, at: 0.1), "The first frame remains the temporal anchor")
  }

  func testConfirmationRejectsExpiredCandidatesAndRestartsWindow() {
    var confirmation = ParticleCaptureConfirmation()
    let payload = ParticleCode.testPayload()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertTrue(confirmation.observe(payload, at: 1), "The one-second upper boundary is inclusive")
    confirmation.reset()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertFalse(confirmation.observe(nil, at: 0.8))
    XCTAssertFalse(confirmation.observe(payload, at: 1.001), "An expired frame cannot confirm")
    XCTAssertTrue(confirmation.observe(payload, at: 1.2), "A new candidate can confirm inside its own window")
    confirmation.reset()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertFalse(confirmation.observe(nil, at: 2))
    XCTAssertFalse(confirmation.observe(payload, at: 2.1))
    XCTAssertTrue(confirmation.observe(payload, at: 2.3))
  }

  func testRecentEarlyRepeatCanConfirmAfterFirstFrameExpires() {
    var confirmation = ParticleCaptureConfirmation()
    let payload = ParticleCode.testPayload()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertFalse(confirmation.observe(payload, at: 0.05))
    XCTAssertFalse(confirmation.observe(nil, at: 1.01))
    XCTAssertTrue(confirmation.observe(payload, at: 1.02), "The recent repeat is still inside the one-second window")
  }

  func testDifferentValidPayloadAndResetInvalidateConfirmation() {
    let payload = ParticleCode.testPayload()
    var other = payload
    other[8] ^= 1
    let checksum = ParticleCode.crc(Array(other.prefix(60)))
    other.replaceSubrange(60..<64, with: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: checksum >> $0) })
    XCTAssertTrue(ParticleCode.valid(other))
    var confirmation = ParticleCaptureConfirmation()
    XCTAssertFalse(confirmation.observe(payload, at: 0))
    XCTAssertFalse(confirmation.observe(other, at: 0.3))
    XCTAssertFalse(confirmation.observe(payload, at: 0.6), "A different valid payload resets agreement")
    XCTAssertTrue(confirmation.observe(payload, at: 0.8))
    confirmation.reset()
    XCTAssertFalse(confirmation.observe(payload, at: 0.9), "A scan cannot reuse the preceding run's candidate")
    XCTAssertTrue(confirmation.observe(payload, at: 1.1))
  }
}
