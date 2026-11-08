# Native Particle Camera Probe

Date: 2026-11-08. Bounded N1a implementation, stacked on the nearby-sync planning PR.

## Task contract

- Goal: install a synthetic particle display/scanner on the owner's selected iPad and iPhone for manual screen-to-camera validation.
- Scope: native optical codec, renderer and camera controller; separate Flutter probe entry; native tests and their iOS-check integration; camera purpose string; build and delivery documentation.
- Protected contracts: SYNC-003/009/010; all accounting, family isolation, authentication and recovery features. The probe entry opens no ledger and reads no Keychain credentials.
- Acceptance: independent RS/CRC vectors, damaged and unrelated inputs, transformed rendered images, camera denial/cancel/background behavior, simulator native tests, signed same-bundle installation and device-side version verification.
- Data/recovery: schema6 and encrypted archives are unchanged. Update over the installed bundle without uninstalling or clearing data. A regular entry build returns to the family app.
- Permission: camera only, requested after selecting the scanner. No microphone, library or local-network access is added.
- Delivery: testing build and a reviewable implementation PR. No merge, tag, TestFlight or App Store publication.
- Out of scope: real enrollment secrets, authorization, Wi-Fi synchronization and financial replication. Optical success must never say that a family is paired.

## Use

Build the existing iOS project with `flutter build ios --release --target lib/particle_probe_main.dart`. Normal builds keep `lib/main.dart` and the existing family entry.

Open the optical probe, select Display on iPad and Camera on iPhone, include the entire circular pattern, and hold steady. The scanner requires two matching frames. Test payloads use a public deterministic fixture and are never enrollment credentials. No camera frames or recovered payloads are persisted or uploaded.

## Evidence

Six native XCTest methods pass on an isolated iOS 18.1 iPhone simulator: independent CRC/parity, errors and erasures, corruption/profile rejection, rotation/mirror/scale, blank/unrelated images, and perspective with blur. The perspective case failed before the locator fix: resampling removed tiny satellites, while the five main centers survived. Satellites now improve ranking rather than gate it; five-center geometry and the full codeword still validate candidates. These tests run through `scripts/check-ios.sh` on both simulator families.

The current host suite retains 131 tests and 26 accounting cases. This probe adds no production dependency and does not change schema or encrypted archives. Installation results are recorded separately; successful installation is not a successful camera trial. The owner performs the screen-to-camera trial after installation; device identifiers, signing material and raw results remain local. The larger negative corpus and N1b enrollment/network/security work remain pending.

## Reliability follow-up contract

The owner reported one successful scan and repeated failures on the selected physical iPhone/iPad pair. Physical optical acceptance is therefore not met. Reproduce failures through the actual native recognizer using smaller screen images and controlled capture degradation before changing the implementation. Limit changes to the optical pipeline, capture controller, native behavioral regressions, testing-build version and delivery documentation. Protect SYNC-003/009/010, payload validation, two-frame confirmation and all existing financial, family, storage and recovery contracts. No new dependency, enrollment, networking, camera-frame persistence or additional permission is authorized by this follow-up. Require passing degradation regressions and existing checks, then install the same-bundle testing update for a separate owner-performed physical retest.

Build 13 deterministically fails when a 340-pixel rendered field shares a 960 x 540 frame with the actual screen caption. The same field without that caption decodes. The area-ranked eight-candidate limit admits connected glyph strokes instead of locator centers; counting those candidates also produces misleading progress feedback. The new caption XCTest failed before the fix. Build 14 filters sparse components by their filled-ellipse occupancy before ranking, and reports data validation only after a five-point geometric match. The format, candidate/time bounds, RS/CRC and two-frame policy remain unchanged. A second regression distinguishes caption-only images from a geometrically located code with an invalid CRC. All eight native tests passed on the isolated iPhone simulator after repair; full candidate and owner-performed physical results remain separate.

## Capture investigation contract

The owner reports build 14 still mostly fails on the selected physical pair. Its caption fix is not sufficient evidence of a physical repair. Investigate the actual luma-copy path, sample confidence and focus/geometry using reproducible inputs and a user-copyable numeric probe summary. Do not persist or export camera images or decoded payloads. Preserve the existing optical profile, full payload validation, two-frame policy, camera-only permission, financial entry, schema and recovery. A differential harness finds 1280 x 720 blurred frames that decode before the current nearest-neighbor reduction but fail after it. Add a regression through the shared capture conversion before retaining native-resolution luma; keep one processing task and late-frame dropping, and expose bounded processing measurements for the physical retest.

The capture-path XCTest first failed on both readable source cases (400-pixel field with 1.2 blur and 460-pixel field with 1.6 blur). The production conversion now copies each luma row at its original width, excluding stride padding, before unlocking the pixel buffer. Both cases then decode; all nine native tests pass on the isolated iPhone simulator. This establishes the sampling defect and its regression repair, not the cause of every physical failure. The larger working image may increase processing cost; physical measurements remain necessary.

In build 15, enable Camera, aim at the complete iPad field for about ten seconds, and tap Copy diagnostic summary. Each new scan resets the counts. Only a user tap writes the displayed numeric summary to the clipboard; no camera images, enrollment secrets or recovered payloads are included. The summary reports build/resolution, processed/geometrically located/decoded frame counts, the minimum uncertain-byte count across in-bounds fits, average/maximum processing time, and the latest focus/exposure values. Focus values are mode, adjusting flag and lens position; they describe the camera without changing its settings. Few located frames point to localization/capture; located frames with no valid decode point to sampling/codeword validation; decoded frames without confirmation justify checking temporal stability. These are diagnostic directions, not proof of a root cause. The summary remains available after capture pauses; a new run or mode switch clears it. Physical acceptance remains pending.
