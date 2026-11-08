# Changelog

Record user-visible changes and data compatibility in English. Release entries are immutable after tagging; corrections belong in a later entry. GitHub source publication is not App Store or physical-device acceptance.

## Unreleased

### Synthetic nearby failure diagnostic build 0.5.0+22

- Preserve build, role, phase, connection state, TLS confirmation, protocol phase, message counters, fixed path categories, numeric network errors and elapsed time before failure cleanup. Export no credential, discovery name, endpoint or payload.
- Reproduce missing failure evidence through actual Network connections: an unfinished TLS handshake times out, while an authenticated peer's oversized frame is rejected. Retain failure, stopped-session and saved-pair assertions; do not relax deadlines, authentication or parsing.
- The owner reports build 21 saved-pair sync and app-process restart sync on both devices, but the router-free/no-internet trial timed out on iPhone. Its cause and physical acceptance remain open. No transport parameter, stored-key, optical, schema6, archive, dependency or permission changes are included.

### Synthetic nearby identity repair testing build 0.5.0+21

- Reproduce matching-key TLS failure with a fixed identity containing a zero byte, separately from a non-UTF-8 identity. Encode the complete identity as Base64 ASCII only at the Network PSK API boundary; preserve the random secret and strict negotiated TLS checks.
- Retain wrong-key/identity rejection and full Bonjour enrollment, permanent-key activation and reopened no-scan reconnect assertions. Update both test endpoints; no schema6, archive, stored test credential, production permission or optical-format change is required.
- Read the native result tree for failure-stage diagnostics so a later bounded stage marker is not lost behind the first assertion. Never export assertion values, credentials or attachments. Physical enrollment, restart, permission and no-router trials remain pending.

### Synthetic nearby connection testing build 0.5.0+20

- Add an independent two-device probe: scan a fresh two-minute particle invitation, explicitly admit on the display device, durably save a pending test pair, then authenticate with the permanent credential before activation and acknowledged test-message exchange.
- Reopen saved pending/active credentials and reconnect by tapping Sync on both ends. Bonjour hints rotate; wrong TLS keys/identities, invalid or oversized frames, wrong attempt bindings and failed writes cannot report completion. Cancellation/background stops the foreground session and ignores late callbacks.
- Store only synthetic trust in a separate nonsynchronizable, device-only unlocked Keychain service. Forget targets its local item. Add local-network/Bonjour declarations without new dependencies, entitlements, platform targets or changes to production credentials, schema6, archives or accounting.
- Preserve the build 19 optical path and two-frame confirmation; dynamic invitations use the same text-free display. The owner reports 5/5 build 19 trials at about one second. The complete optical matrix and physical build 20 enrollment, permission, restart and no-router trials remain pending.
- Test native protocol, real loopback TLS rejection, isolated Keychain behavior, Bonjour enrollment/reopen, cancellation and reflow. Native XCTest now uses certificate-free ad-hoc simulator signing because unsigned hosts cannot access Keychain; no assertion is skipped.

### Optical display testing build 0.5.0+19

- Add a clean full-screen particle display with an accessible exit icon, safe-area spacing and orientation/window reflow. The iPad display action opens it; exiting returns to the probe controls.
- Rank locator candidates using boundary compactness as well as area and optional satellites, so filled text glyphs are less likely to displace real centers. Preserve the optical profile, eight-candidate/time bounds, full RS/CRC/profile validation, two-frame confirmation, camera settings and numeric diagnostics.
- Reproduce the old display's text interference with fixed caption renders; retain blurred satellite-loss coverage and add clean-display decoding and open/exit regressions. The old control page still has small/blurred text interference limits; use full-screen display for the physical retest.
- The owner completed one build 18 physical confirmation after 13.3 seconds with three decodes and aligned geometry. This establishes one success, not optical reliability. Build 19 needs its own physical trial. Schema6, archives, credentials and same-bundle recovery are unchanged.

### Optical geometry diagnostic build 0.5.0+18

- Add transient candidate rings and a dashed data-sampling boundary to the live preview, plus run-best field dimensions, minimum bit-position spacing, mean differential luminance and fifth-point residual in the copied numeric summary. No images or recovered payloads are retained or exported.
- Label geometric matches as candidates rather than proven locator detection; distinguish one valid frame from completed confirmation. Verify rendered field coordinates, locator-only unreadable geometry, blank-frame clearing and rotated/mirrored preview coordinates.
- Build 17 still physically failed with 30 processed frames, 21 geometric matches, zero decodes and 93 minimum uncertain bytes. The owner reports near-full framing. Build 18 gathers distinguishing evidence; it does not change recognition decisions, camera settings, optical format, schema6 or recovery, and does not claim an optical repair.

### Optical low-contrast testing build 0.5.0+17

- Retain erasure-based decoding and try the same sampled bits once without erasures when uncertain samples prevent recovery. The existing decoder still requires complete RS, CRC and format/profile validation; unknown-error correction remains limited to 16 bytes.
- Add rendered-image regressions for blurred low-contrast fields, another valid payload, invalid CRC and an unsupported profile with valid CRC. Both new test methods failed before the repair. Preserve the optical profile, camera settings, two-frame timing, schema6 and recovery.
- The owner reports build 16 never confirmed: 52 processed frames, 39 geometric matches, zero valid decodes and 87 minimum uncertain bytes. Synthetic reproduction and passing checks do not establish a physical repair; build 17 needs a separate camera trial.

### Optical confirmation testing build 0.5.0+16

- Retain a valid candidate across undecodable frames inside the agreed 100 ms to one-second confirmation window. Preserve the first temporal anchor when a repeat arrives too early; different valid payloads, expiry and scan lifecycle reset still prevent stale confirmation.
- Add native regressions for intermittent rendered-image decodes, minimum/maximum timing, different valid payloads and reset. Two cases failed before repair; an additional sliding-window case rejected a premature-expiry implementation. Add confirmation status, elapsed time and the shortest valid-decode interval to the user-copied numeric summary.
- The build 15 physical summary reported four valid decodes among 88 processed frames; it did not include their intervals or the final confirmation status. Retain complete optical validation, camera settings, schema6 and recovery. Physical reliability requires another trial.

### Optical capture testing build 0.5.0+15

- Preserve native-resolution 720p luma and respect padded camera rows. A regression through the actual capture conversion reproduces previously readable blurred particle fields failing after nearest-neighbor reduction.
- Add an explicitly copied numeric diagnostic summary for capture, geometry, valid decoding, sample confidence, processing time and camera focus/exposure. No camera images or decoded payloads are saved or copied. Retain the optical format, validation, two-frame confirmation, camera permission and schema6.
- Physical trials of builds 13 and 14 remain unreliable. Build 15 requires a new owner-performed trial; synthetic passing results do not establish a physical repair.

### Optical reliability testing build 0.5.0+14

- Reject sparse screen-lettering components before ranking filled circular locator candidates. A native regression reproduces a readable particle field failing solely because a nearby screen caption displaces its locators in build 13.
- Show the data-validation hint only after a five-point geometric match, rather than merely counting dark candidate components. Retain the particle format, RS/CRC rejection, two-frame confirmation, camera-only permission and schema6. Physical reliability requires a new owner-performed trial.

### Optical testing build 0.5.0+13

- Add a separate particle-camera probe entry with native display, bounded localization, projective sampling, Reed-Solomon correction and two-frame confirmation. Only public synthetic payloads are used; no family enrollment or synchronization occurs.
- Add a camera purpose string and request access only after selecting the scanner. Retain schema6, archive compatibility, Bundle ID and installed family data; the probe does not open the ledger.
- Preserve a failing perspective/blur regression and correct locator ranking when small satellite dots disappear during resampling. Physical screen-to-camera success remains owner acceptance, separate from native synthetic tests.

### Simplification candidate 0.5.0+12

- Focus the wish home on its goal and one concrete feedback hint; keep the complete configured task area in Tasks.
- Submit accepted temporary tasks directly from their cards, retain paused/cross-day promises, and preserve each child's page scroll when changing tabs or window size.
- Navigate wishes through list/detail/edit/receipt pages, make the complete primary card tappable, preserve the originating context after editing, and start explicitly linked gift advances from the child's wish detail. Keep amount/progress semantics independently readable and actual gift receipt parent-only.
- Give money one primary available balance, directly reachable holding/debt records, a recent/full classified ledger, and a direct withdrawal form. Group five plans by fixed/variable terms and confirm deposits once with amount-specific promises and risk; retain invalid input for correction. Consolidate hypothetical growth and weekly contributions in the interactive classroom, separate from actual returns.
- Separate parent Pending, Child, and Family responsibilities. Handle money handover and advance offer/funding directly from each pending record, exclude child-waiting offers from actionable counts, separate budget/name forms, and retain one profile selector and one temporary-task creation entry. Keep internal-page close separate from exit/background locking.
- Retire the production town route and duplicate task/wish/wallet/parent/growth panels under ADR 0003; keep scene data, assets and internal lifecycle/navigation tests. Move appearance under More, default to system, label parent access, remove routine saved-state badges, and return existing real families directly to the selected child while keeping demos/explicit home return separate. Wait for route disposal before disposing its controller.
- Retain schema6, authenticated schema4/5/6 backups, existing task/holding promises, and all financial/parent rules. See the [implementation plan](docs/27-interface-simplification.md) and [ADR 0003](docs/adr/0003-wish-journal-simplification.md) for the remaining bounded tasks.

### Experience candidate 0.4.0+11

- Preserve the parent session when its nested finance dialog closes; retain exit/profile/background locking.
- Share recurring task standards/pay across the family while keeping task instances, funds, budgets, and permission separate.
- Set independent family rates and versions for the three existing fixed products; preserve original holding promises.
- Add parent-enabled, real-money low/high-volatility teaching plans with bounded 30-day gains/losses, budget reservation, and signed settlement.
- Replace the prose classroom with native curve playback, random alternative journeys, compound-growth comparisons, and dividend animations; support time stepping, pause/resume, and reduced motion.
- Upgrade schema1-5 to schema6, retain legacy templates and original snapshots, and read authenticated schema4/5/6 backups. The active child's future templates initialize shared terms; older binaries cannot read upgraded live data. See [ADR 0002](docs/adr/0002-shared-agreements-and-teaching-market.md).

### Engineering

- Add a contribution contract, stable regression IDs, release/recovery standards, code/test standards, and an ADR process for human and AI work.
- Add PR ownership/templates, mandatory repository and iOS simulator CI, and full-history secret scanning. Review GitHub protection settings separately from files in this repository.
- Align the Podfile checksum in the lockfile without changing dependency versions; pin CI Ruby 4.0.5, CocoaPods 1.16.2, and JSON 2.18.0. Check deployment-mode pod metadata before native builds.
- Attach native tests through authenticated, process-scoped retained simulator logs to avoid Flutter's live-log startup race; keep independent restart and all business assertions.
- Governance-only changes retained the 0.3.6+10/schema5 baseline. The experience candidate above advances app/build, schema, and archive payload; no binary distribution is implied.

### Fixed

- Stack the finance-panel illustration and dialogue in narrow windows to prevent overflow found by the new simulator gate.
- Wait for native backup-save completion before asserting the widget result; retain all export/credential assertions.

## 0.3.6+10 - Local-feature baseline

- Conceal revealed secrets and clear secret input on leaving the foreground while retaining ordinary forms.
- Correct onboarding guidance for parent recovery codes.
- Publish English repository material and ASCII paths while preserving Chinese UI and business inputs.
- Preserve normalized local accounting, two-child isolation, wish/task workflows, encrypted backup/recovery, and schema 1-4 upgrades to 5.

Source baseline: `0ac9298829c47e3df4160a41dae6a0cb3f9424ad`, tag `v0.3.6-local.1`. See the [baseline manifest](evidence/public/releases/v0.3.6-local.1.json). This is a local-feature recovery point; CloudKit and complete physical-device regression remain pending.
