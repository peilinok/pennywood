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
