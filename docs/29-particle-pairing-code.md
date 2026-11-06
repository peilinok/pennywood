# Custom Particle Pairing Code and Recognition

Date: 2026-11-06. Status: accepted optical direction; experimental format and decoder proposed, not production-ready. [ADR 0005](adr/0005-custom-particle-pairing.md) refines [ADR 0004](adr/0004-nearby-family-sync.md). The owner explicitly requested custom visual encoding and recognition after reviewing the standard QR-based preview.

## 1. Contract and scope

The first-time pairing graphic is a circular particle field with no square boundary, three QR finder boxes, embedded QR, or dependency on the system barcode decoder. Pennywood's own scanner detects its geometry and recovers a short enrollment payload. Decoration may breathe around a stable code. Ordinary synchronization remains the agreed two-tap foreground Wi-Fi flow; financial rules and single-primary authority do not change.

This task changes planning documents and local visual/codec experiments only. Protect SYNC-003/004/005/008/009, AUTH-001/002, FAMILY-002 and all accounting/recovery contracts. Add SYNC-010 for custom optical decoding. No app permissions, native code, production dependency, schema, account or release is changed by this planning revision.

The optical format transports data; it is not an encryption, authentication or permission system. A photograph can copy it. Enrollment expiry, one-time use, parent confirmation, authenticated networking and revocation still belong to the [implementation plan](28-nearby-family-sync-plan.md). No Apple private visual code or account protocol is reverse-engineered or claimed compatible.

## 2. Appearance and stable layers

Use paper, chestnut, green and blue-gray from the existing design system. Three separately rendered layers have different contracts:

| Layer | Appearance | Recognition contract |
|---|---|---|
| Data particles | Dense, circular, sunflower-like distribution; no square lattice or finder boxes | Fixed coordinates during enrollment. Each particle occupies one of two known nearby positions; position carries a bit, color does not |
| Five locator constellations | Small round central points with tiny satellite dots, integrated into the outer particle field at asymmetric angles | Fixed, high-contrast geometric landmarks for orientation, scale and projective mapping; no blinking, drifting or obscuring them |
| Decorative particles | Softer sparse cloud outside the data/locator guard regions | May change opacity or move slightly; cannot become locator/data candidates or invade protected sampling regions |

The drawing is a flat optical field with a soft spherical visual impression. Do not apply a real 3D rotation, depth-dependent parallax or a shader that displaces data particles during capture. Under Reduce Motion, all decoration becomes static and the same single image still decodes. Use luminance contrast and geometry for decoding; differences in white balance must not change bits.

A first render can use an approximately 280-340 pt optical area with responsive margins. This is an experiment target, not a guarantee that 768 symbols remain distinguishable at every camera distance. Validate the whole symbol including outer locators, not just the center. Keep captions, mascots, focus brackets and success animation outside protected regions until capture is complete.

## 3. Experimental physical format: PWPC v1

This is a concrete N1 experiment profile, not a frozen wire standard. Change its profile/version if geometry, layout, error correction or interpretation changes. The native implementation must use checked-in golden vectors rather than infer a layout from a screenshot.

### Payload and capacity

| Offset | Length | Field |
|---|---:|---|
| 0 | 4 bytes | Fixed `PWPC` marker |
| 4 | 1 byte | Optical format version, initially 1 |
| 5 | 1 byte | Physical layout profile, initially 1 |
| 6 | 2 bytes | Reserved, zero in v1; unknown values rejected |
| 8 | 16 bytes | Random enrollment session ID; also used as an opaque Bonjour rendezvous hint |
| 24 | 32 bytes | Random one-time bootstrap secret; never the persistent pair credential |
| 56 | 4 bytes | Expiry hint, unsigned big-endian Unix seconds |
| 60 | 4 bytes | CRC-32 over bytes 0-59, stored big-endian |

The payload is exactly 64 bytes. CRC uses CRC-32/ISO-HDLC (polynomial `0x04c11db7`, reflected input/output, initial register and final XOR `0xffffffff`), matching the experiment's `zlib.crc32`. The session ID does not disclose the family or device owner. The expiry hint is for display/early rejection; the primary's live enrollment record is authoritative because camera-device clocks can differ. Do not put child names, ledger records, IP addresses, stable Bonjour instance names, local parent PINs, permanent keys or variable-length JSON into the optical field.

Apply a shortened Reed-Solomon RS(96,64) code over GF(256): 64 data bytes plus 32 parity bytes, 96 bytes / 768 bits total. The local experiment uses primitive polynomial `0x11d`, generator 2, first consecutive root 0 and eight-bit symbols. Serialize bytes in table order, bits most-significant first. Freeze parity ordering with independent vectors before implementing the native codec.

The theoretical bound is at most 16 unknown erroneous bytes, or an error/erasure combination satisfying `2e + s <= 32`, where erasure locations are supplied. It is not 16 bad dots, not 32% of an arbitrary image, and not permission to cover a large region. Claim erasure support only if the selected implementation actually accepts erasure positions. CRC rejects accidental corruption; neither CRC nor Reed-Solomon authenticates a peer. Decoding beyond the correction bound can miscorrect, so the later field checks and authenticated enrollment remain mandatory.

### Particle mapping

Use 768 fixed addresses in a circular sunflower distribution. For the experiment's 520 x 520 coordinate space, center C is (260,260). For address j in 0-767:

```text
theta(j) = j * pi * (3 - sqrt(5))
radius(j) = 174 * sqrt((j + 0.5) / 768)
base(j) = C + radius(j) * (cos(theta), sin(theta))
offset(j) = 2.35 * (-sin(theta), cos(theta))
bit 0 position = base - offset
bit 1 position = base + offset
bit i uses address (73 * i + 19) mod 768
```

One dark particle is drawn at the selected position, so total data-dot count is constant. The two candidate positions provide a differential luminance measurement, avoiding a color alphabet or a fragile present/absent threshold. Interleaving disperses contiguous encoded bits spatially; quantify its effect on burst damage instead of assuming it always helps Reed-Solomon recovery.

Place five round locator constellations at radius 210 and angles -94, -19, 59, 144 and 221 degrees. Their asymmetric arrangement disambiguates orientation and correspondence. Four non-collinear points can estimate a planar homography; the fifth supplies an additional geometric check. If too few reliable locators remain, request better framing rather than guessing pose. Data and locator geometry is public format information, not secret security material.

The current experiment renders data radii around 1.65 units, central locator radii 4.7, and six small locator satellites around each center. These are calibration values only. Before freezing a profile, verify minimum separation across both possible bit positions, raster scale, camera sampling, blur and projective compression. Decorative particle placement excludes each locator's guard area and the data field.

## 4. iOS recognition pipeline

AVFoundation supplies video frames through `AVCaptureVideoDataOutput`, `CMSampleBuffer` and `CVPixelBuffer`; it does not decode this format. `AVCaptureMetadataOutput` and Vision's barcode request recognize supported barcode types and cannot be configured with an arbitrary PWPC symbology. Vision/Accelerate/Core Image may assist processing, but the locator, sampling, correction and payload checks are our implementation. Use APIs available at iOS 13. [O1-O5]

1. Start camera capture only for Join family / explicit re-pairing, after camera permission. Use a camera-only session; no microphone or photo-library permission.
2. Configure/start/stop capture on an owned serial session queue. Handle frames on a serial processing queue, discard late frames, and allow at most one expensive decode at a time. Return buffers promptly and stop on cancel/background. Never accumulate an unbounded video queue. [O1-O3]
3. Normalize frame orientation and mirroring from the actual output connection/buffer, not just the displayed preview. Crop a sufficiently large user-visible scan region; initially analyze at a bounded rate of about 10 frames/second, measured on the target devices. Do not require exact user alignment.
4. Convert to luminance, adapt contrast and detect particle/locator candidates. Find plausible five-constellation arrangements, score their relative geometry, estimate a projective transform, and reject degenerate or ambiguous fits. Bound candidate count and processing time on ordinary textured backgrounds.
5. Map each known two-position address through the fitted transform. Compare local contrast for both positions, produce the bit and confidence, and map uncertain bits to known byte erasures where supported. Recover the 96-byte codeword in inverse interleave order.
6. Run bounded Reed-Solomon correction, CRC, marker/version/profile/reserved/length checks. Reject unsupported profiles and excessively damaged candidates before opening any networking session. Do not log recovered secrets.
7. Require the same complete valid payload in at least two independently acquired frames separated by at least 100 ms within one second. Disagreement resets the candidate. This is an initial debounce/false-trigger policy, not cryptographic anti-replay or a guarantee against correlated visual mistakes.
8. Freeze the captured result, stop camera processing and transfer it to enrollment. Show Connecting to the family; show Paired only after the primary approves the grant and both sides durably activate it. A valid picture alone never creates parent authority.

Scanner feedback distinguishes searching, move closer, include the whole pattern, hold steady, excessive glare, expired session and unsupported app version. Do not automatically fall back to a conventional QR code; the user rejected that visual direction. If the format fails N1, retain the current local-only product and revise the optical design with measured evidence.

## 5. Animation, capture and threat boundaries

Keep the payload constant throughout its short-lived pairing window. Automatic two-minute expiry or explicit regenerate creates a new session and invalidates the old one; do not cycle data frames continuously. Do not spread bits across an animation, require a particular animation phase, or encode in color/hue/flicker. This keeps a static reduced-motion image meaningful and reduces rolling-shutter complexity.

Soft decorative breathing is allowed only outside protected regions and below detection contrast thresholds. Test every animation phase, system dark/light modes and screen brightness. The locator cannot be treated as decoration and animated away. Do not use visible rapid flashing to improve recognition.

The custom code is specific to the app format, not confidential. A screenshot or recording can reproduce it, and an adversary can generate a structurally valid code. Single-use primary-side enrollment state, parent approval, the authenticated network handshake and scope validation are the trust mechanism. Retain the TLS-PSK candidate's disclosed lack of forward secrecy from the main plan; visual novelty does not fix it.

## 6. Local evidence and its limits

A disposable Python experiment generated a synthetic 64-byte payload, RS-encoded it, rendered the particles, independently detected locators from the resulting pixels, estimated geometry, sampled dots and recovered the original payload. The detector does not receive the generator's transform or pre-labelled anchor locations. Reed-Solomon uses a local research-only `reedsolo` 1.7.0 package; this does not select or install a production iOS dependency.

The sanitized [experiment summary](../evidence/public/particle-code-experiment.json) records 18 passing checks: base image, one 31-degree rotation, one mirror, one perspective warp, Gaussian blur radius 0.6, scale to 85%, removal of 12 encoded byte-symbols, four additional deterministic payloads, 1/8/16 byte-error correction, 20 known erasures, and rejection of blank, unrelated particles and a tested 40-symbol loss.

These are isolated rendered images, not camera video, arbitrary scenes, reliability statistics or security acceptance. Only one example per listed transformation was exercised. Full-frame clutter localization, motion, real display/camera resampling, severe perspective, glare, privacy prompts, performance/energy and temporal consistency are not validated. The preview uses public synthetic bytes and establishes no connection. Do not generalize the 18 cases into a false-positive rate or a successful iPhone/iPad acceptance claim.

Local probe sources, generated images and environment dependencies remain outside the published app. Future N1 must add reviewable native source, independent codec vectors and device results before this design can be called implemented.

## 7. Updated N1 acceptance and dependencies

Split the existing N1 gate into linked deliverables; neither can be skipped before production pairing:

| Gate | Deliverable | Required result |
|---|---|---|
| N1a Optical format and native recognition | Fixed profile, Swift-compatible encoder/decoder, golden vectors, locator/capture pipeline and styled renderer | Payload round trips; error/erasure bounds; invalid/profile/mirror/orientation handling; bounded candidate processing; no QR fallback |
| N1b Two-device enrollment proof | Existing Network transport experiment driven by decoded synthetic sessions | Native camera captures from the other device's display, connects to the corresponding session, rejects expiry/reuse and wrong peers, survives restart/permission failure |

Use platform frameworks for capture/rendering. Choose a reviewed, license-compatible error-correction implementation with explicit error/erasure behavior; do not copy an unsuitable licensed decoder or add OpenCV merely to avoid evaluating native processing. If a dependency is necessary, justify binary size, maintenance, license and iOS13 support in its implementation PR. Standard error-correction implementation is distinct from inventing a cryptographic protocol.

Physical matrix: iPhone scans iPad and iPad scans iPhone; selected supported OS generations; indoor bright/dim lighting; low/high display brightness; matte/gloss/reflective conditions; several distances, rotations and tilts; partial occlusion of data versus locator loss; motion and rolling shutter; screen-refresh/camera aliasing and moire; dark mode, Reduce Motion, animations, enlarged text, resized windows; background/interruption and thermal load. Avoid minimum-OS claims based on a recent OS device alone.

Keep the main plan's proposed normal-condition scan target of 19/20 trials within three seconds as a gate to measure, not an achieved rate. Add a repeatable negative corpus of at least 1,000 non-code images and at least 100 standard-barcode, malformed-PWPC or unrelated-particle variants: no payload handoff to enrollment in that corpus. Syntactically valid PWPC images are a separate authentication/replay suite, not negative optical examples; invalid/expired credentials must still fail the network stage even when the visual payload passes. Zero observed false positives in a finite corpus is not a general probability bound.

## 8. Sources actually read

- O1: [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput) and [setSampleBufferDelegate](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/setsamplebufferdelegate(_:queue:)). Camera buffers and serial callback queue.
- O2: [alwaysDiscardsLateVideoFrames](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes) and [TN2445](https://developer.apple.com/library/archive/technotes/tn2445/_index.html). Bounded real-time capture and dropped-frame handling.
- O3: [AVCaptureSession.startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning()). Blocking capture startup; use a session queue.
- O4: [VNDetectBarcodesRequest](https://developer.apple.com/documentation/vision/vndetectbarcodesrequest) and [VNBarcodeSymbology](https://developer.apple.com/documentation/vision/vnbarcodesymbology). Supported barcode families; not a custom-format registration interface.
- O5: [QA1744: Setting the orientation of video with AV Foundation](https://developer.apple.com/library/archive/qa/qa1744/_index.html). Actual buffer rotation and transform costs; verify API availability for iOS13.
- O6: [ZXing ReedSolomonDecoder source](https://github.com/zxing/zxing/blob/master/core/src/main/java/com/google/zxing/common/reedsolomon/ReedSolomonDecoder.java). Example error decoder; does not supply an erasure-position input.
- O7: [libfec manual](https://github.com/quiet/libfec/blob/master/rs.3). Standard shortened Reed-Solomon and erasure-aware interfaces; source evidence, not a selected production dependency.
