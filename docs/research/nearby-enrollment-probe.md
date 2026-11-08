# Native Nearby Enrollment Probe

Date: 2026-11-08. N1b API research for the [nearby synchronization plan](../28-nearby-family-sync-plan.md), following the separate [optical probe](particle-camera-probe.md).

## Task contract

- Goal: establish the supported iOS API and minimum recoverable handshake for a two-device synthetic enrollment probe, then inform its implementation.
- Scope: this research note and an ignored, isolated Swift API typecheck. No production implementation, dependency, branch change, commit or distribution is performed by this research task.
- Protected contracts: SYNC-003/004/008/009/010 and all existing accounting, family isolation, local authentication and data recovery behavior.
- Acceptance: check API availability against the installed iPhoneOS SDK; typecheck the exact TLS, discovery, permission and isolated Keychain calls for iOS 13; cite Apple-owned sources; identify all remaining physical and security acceptance gaps.
- Data/recovery: no schema6, archive, parent credential or family grant change. A probe implementation must use separate test credentials, retain existing family data during same-bundle updates, and expose a narrowly scoped way to forget only its own test pairing.
- Out of scope: real child data, financial replication, production device authorization, cloud/BLE/acoustic fallback and additional platform targets.

## Findings and evidence boundary

The older Network framework API supports the proposed iOS 13 baseline. `NWBrowser` requires iOS 13; `NWListener`, `NWConnection`, `NWParameters(tls:tcp:)` and `includePeerToPeer` are available earlier. Use `NWListener(using:)` followed by its `service` property; the `NWListener(service:using:)` convenience initializer requires iOS 16. The installed iOS 18.1 SDK interfaces and a successful `arm64-apple-ios13.0` typecheck establish these static facts. They do not establish discovery, radio paths or TLS interoperability on either physical device. [S1, S2, SDK]

Apple's TicTacToe sample uses `sec_protocol_options_add_pre_shared_key`, bridges Swift `DispatchData` to `__DispatchData`, and appends `TLS_PSK_WITH_AES_128_GCM_SHA256`. It enables peer-to-peer links independently on browsing and connection/listener parameters. Adopt the API pattern, not the sample's human passcode as a credential policy. Pennywood's candidate supplies a random 32-byte secret and an opaque session identity. [S2, S3]

Apple TN3213 explicitly limits TLS-PSK to the older Network API, without TLS 1.3 or QUIC. TLS-PSK is therefore a bounded prototype candidate. It is not a reason to copy iOS 26 APIs or accept arbitrary certificates. [S1]

## Compilable TLS and networking calls

The following core calls were typechecked with Swift from Xcode 16.1 / iPhoneOS 18.1, deployment target iOS 13.0, with warnings treated as errors. The isolated file also typechecks permission classification and Keychain insertion below. This is an API excerpt, not a complete session manager: the implementation must retain objects, install bounded state/error/lifecycle handlers, authenticate before reading application frames, and persist before reporting completion.

```swift
import Foundation
import Network
import Security

let probeService = "_pw-probe._tcp"
let expectedCipher = tls_ciphersuite_t(
    rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256)
)!

func dispatchData(_ value: Data) -> DispatchData {
    value.withUnsafeBytes { DispatchData(bytes: $0) }
}

func makeParameters(secret: Data, identity: Data) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    let options = tls.securityProtocolOptions
    sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
    sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
    sec_protocol_options_append_tls_ciphersuite(options, expectedCipher)
    sec_protocol_options_add_pre_shared_key(
        options,
        dispatchData(secret) as __DispatchData,
        dispatchData(Data(identity.base64EncodedString().utf8)) as __DispatchData
    )
    let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    parameters.includePeerToPeer = true
    return parameters
}

func makeListener(secret: Data, identity: Data, hint: String) throws -> NWListener {
    let listener = try NWListener(using: makeParameters(secret: secret, identity: identity))
    listener.service = NWListener.Service(name: hint, type: probeService)
    return listener
}

func makeBrowser() -> NWBrowser {
    let parameters = NWParameters.tcp
    parameters.includePeerToPeer = true
    return NWBrowser(for: .bonjour(type: probeService, domain: nil), using: parameters)
}

func makeConnection(
    endpoint: NWEndpoint, browser: NWBrowser, secret: Data, identity: Data
) -> NWConnection {
    browser.cancel()
    return NWConnection(to: endpoint, using: makeParameters(secret: secret, identity: identity))
}

func hasExpectedTLS(_ connection: NWConnection) -> Bool {
    guard let metadata = connection.metadata(definition: NWProtocolTLS.definition)
        as? NWProtocolTLS.Metadata else { return false }
    let security = metadata.securityProtocolMetadata
    return sec_protocol_metadata_get_negotiated_tls_protocol_version(security) == .TLSv12
        && sec_protocol_metadata_get_negotiated_tls_ciphersuite(security) == expectedCipher
}
```

The TLS configuration/metadata APIs used here that take or return `tls_protocol_version_t` or `tls_ciphersuite_t` are available on iOS 13. `add_pre_shared_key` is available on iOS 12. The cipher code point is `0x00A8`; AES-128 remains AES-128 even with a 256-bit PSK. Reject a missing TLS metadata object, a different version or a different suite at `.ready`, before exchanging any credential or other application payload. Never add a plaintext retry or a certificate verification callback which always returns true. SDK declarations prove that these calls exist; a wrong-key physical test must still establish that the implementation refuses an unauthenticated peer. [S1-S3, SDK]

Runtime qualification: the installed Network implementation fails the matching-key loopback handshake when the raw identity contains a zero byte. A fixed non-UTF-8 identity without zero bytes succeeds. Build 21 therefore Base64-encodes the complete contextual identity into ASCII at this API boundary. The secret remains its original random bytes; no encoding is applied to stored credentials. This is a simulator-observed compatibility constraint, not a limitation inferred from the API signature or a physical-device result.

`sec_protocol_options_set_pre_shared_key_selection_block` is available on iOS 13. Its SDK contract says the **client** chooses a PSK identity given an optional server hint; its completion takes the chosen identity, not the secret. It is not a listener-side authorization callback. Apple's single-key sample does not install it, so the probe need not add it merely to use one configured key. If the implementation uses an explicit single-identity client selection, this form also typechecks:

```swift
let identifier = dispatchData(Data(identity.base64EncodedString().utf8))
sec_protocol_options_set_pre_shared_key_selection_block(options, { _, _, complete in
    complete(identifier as __DispatchData)
}, queue)
```

Use a fresh parameter configuration for the intended bootstrap or permanent credential. Do not infer a peer's authorization from a Bonjour name, a TLS selection callback or a self-declared role. The production grant check belongs after authentication and before business data access. [S3, SDK; application recommendation]

## Discovery, permission and lifecycle behavior

Opt in with `includePeerToPeer = true` on the browser and on the TLS parameters used by both the listener and outgoing connection. An accepted `NWConnection` is supplied by the listener and uses its configuration; do not create a second listener for it. Cancel browsing before opening the selected connection. Apple warns that continued peer-to-peer browsing can harm connection performance. Stop discovery, listener and connections on cancel/background, ignore obsolete callbacks using a session generation, and restart explicitly when the user resumes. The foreground-only policy is Pennywood's product decision, not a claim of background delivery support. [S1-S3; application recommendation]

Declare the exact fixed service type in `NSBonjourServices` and explain this user-started nearby connection in `NSLocalNetworkUsageDescription`. Existing optical scanning separately needs `NSCameraUsageDescription`. On iOS 14+, Bonjour registration, browsing and resolution all require local-network access. A raw listening TCP socket's different permission rule does not exempt Bonjour registration. Ordinary use of the declared service does not require the multicast entitlement; arbitrary service browsing, service enumeration and raw multicast/broadcast have different requirements. No microphone permission, Core Bluetooth service, CloudKit container or speculative background capability follows from this API choice. [S4, S5]

Classify observable failures rather than guessing the privacy setting:

| Observation | Accurate interpretation and action |
|---|---|
| Browser `.waiting(.dns(kDNSServiceErr_PolicyDenied))` | Local-network policy currently blocks this operation; explain local-network access and offer Settings/retry |
| Connection `.waiting` and `currentPath?.unsatisfiedReason == .localNetworkDenied` | Local-network access blocks this connection; guard the path property with `#available(iOS 14.2, *)` |
| Empty results until the discovery deadline | No matching peer was found in the allotted window; this alone does not prove permission denial or that Wi-Fi is off |
| Other `.waiting` or `.failed` error | Preserve its bounded error category for diagnostics; do not recategorize every POSIX/DNS/TLS error as permission denial |
| First local-network prompt is pending | The initial operation may be denied before the user answers; do not persist an irreversible denied state or erase a saved pairing |

These classifiers typecheck for iOS 13:

```swift
func isPolicyDenied(_ error: NWError) -> Bool {
    if case let .dns(code) = error {
        return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
    }
    return false
}

func isPathDenied(_ connection: NWConnection) -> Bool {
    if #available(iOS 14.2, *) {
        return connection.currentPath?.unsatisfiedReason == .localNetworkDenied
    }
    return false
}
```

TN3179 says the simulator does not support local-network privacy. Permission denial and changing consent in Settings therefore require a physical-device test. It also explains that a Bonjour operation with peer-to-peer Wi-Fi enabled may trigger the alert even without a Wi-Fi status icon. Do not infer a radio state from that icon or hard-code interface names. [S4]

Apple documents peer-to-peer Wi-Fi without configuring a shared network, but this is not evidence that Pennywood has achieved it. Test the selected iPhone/iPad without a common router and without internet, in both directions. Record whether radio controls were changed in Control Center or Settings: these controls have different effects. Do not advertise this acceptance until the test passes. [S1, S6, S7]

## Isolated credentials and recoverable activation

Use a separate generic-password service such as `pennywood.nearby.enrollment-probe.v1`, with opaque account identifiers. Set `kSecAttrSynchronizable` to `false` and accessibility to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Do not reuse or change the production parent credential service. The SDK explains that `ThisDeviceOnly` items do not migrate to another device after backup restoration; missing keys therefore require explicit test re-pairing, not recreation of authority from an identifier. This policy limits availability while locked, matching a foreground probe. [S8, SDK]

The isolated insertion shape typechecks; the complete implementation must check `OSStatus`, handle duplicate items using a matching scoped update, and never erase a different service/account:

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "pennywood.nearby.enrollment-probe.v1",
    kSecAttrAccount as String: account,
    kSecAttrSynchronizable as String: false,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    kSecValueData as String: credentialEnvelope,
]
let status = SecItemAdd(query as CFDictionary, nil)
```

For the probe, one encoded Keychain item containing a credential and its phase can reduce cross-store repair work. If nonsecret metadata is stored separately, Keychain and that store are not one transaction. Either approach needs explicit pending states and crash recovery. The following is the minimum application protocol recommendation, not behavior provided automatically by Network framework:

1. Generate a fresh session ID and random 32-byte bootstrap secret. Keep the bootstrap material in memory only, expire it after two minutes using the host's elapsed-time deadline, and invalidate it on cancellation/background. An optical expiry hint is not authorization and the host must enforce expiry even if clocks differ.
2. Discover only the matching opaque session hint, then authenticate with the bootstrap PSK. Verify negotiated TLS before application frames. Bind an attempt ID, both opaque device IDs and the explicitly selected test role/scope to the offer. Keep this a synthetic test grant; scanning alone must never activate family access.
3. After the designated host's explicit confirmation, persist a fresh permanent pair credential in the host's prepared state before sending the install offer. The joiner persists that credential and the bound attempt in prepared state before acknowledging installation. Failed persistence produces failure, not success.
4. Finish activation using the permanent credential, with the same attempt and peer bindings. The host durably marks the attempt active before sending its active result; the joiner durably marks it active before showing completion. The probe still exchanges no real family state.
5. If the final result is lost, a prepared joiner reconnects with that same permanent key and asks the status of the same attempt. An active host repeats the result; a matching prepared host resumes the unfinished step. Duplicated frames or retries must not create a second peer or rotate the credential underneath the other device.
6. On restart, preserve a valid prepared record for bounded recovery, but never enable ordinary sync from a prepared state. Missing/malformed/mismatched records require an explicit probe recovery action. Canceling an expired initial session must not delete a successfully active pair. Cleanup must target only expired/orphaned probe records and never all app Keychain items.

Use bounded TCP framing; a single `receive` callback is not a message boundary. Validate frame length/type/version and attempt binding before allocating or accepting a message. Handle fragmented headers/bodies and multiple frames in one read; bound total buffered bytes, time without progress and accepted connections. A send-completion callback only indicates local transport progress, not the remote durable write. Parent approval, credential installation, activation and later financial success remain distinct states. [S1, S2; application recommendation]

## Remaining gates

| Evidence | Status of this research task |
|---|---|
| iOS API availability and exact Swift types | Checked against iPhoneOS 18.1 SDK headers/interfaces |
| iOS 13 deployment-target typecheck | Passed, warnings as errors, isolated API file; no production build outputs changed |
| Apple-owned networking/privacy/sample sources | Read; sample source downloaded only into ignored research scratch |
| Native session state-machine tests and interrupted writes | Implementation responsibility; not executed by this research task |
| Actual TLS negotiation and wrong-key/identity refusal | Pending physical implementation test |
| Discovery, no common router, no internet and radio-state combinations | Pending physical test; API support alone is insufficient |
| Permission denial, Settings recovery, background/lock and restart recovery | Pending physical test |
| Production enrollment security and real family authorization | Out of scope; not approved by a synthetic probe |

Pure TLS-PSK with this non-DHE cipher suite provides no forward-secrecy guarantee. Disclosure of the enrollment PSK together with recorded handshake traffic may expose the permanent credential transferred during that session; a short optical expiry does not repair that property. TLS version/suite checks do not add forward secrecy. This is disclosed in the accepted plan and remains a production security decision, not a problem to patch with a custom cryptosystem, permissive trust callback or plaintext fallback. No device identifiers, secrets, frames, signing records or raw logs belong in public evidence. [S1, S9; plan section 5]

## Build 20 implementation contract and status

Goal: one synthetic pair completes a fresh particle scan, explicit admission, durable credential installation, permanent-key activation and acknowledged test-message exchange. Later foreground Sync actions reopen that pair without rescanning. Scope is the native probe protocol/Keychain/Network/UI, narrow renderer/scanner injection, the separate Flutter entry, iOS declarations/project registration, focused tests and delivery documentation. Production family grant/child scope, accounting, schema7, cloud/BLE/acoustic fallback, merge and external distribution remain excluded. Protect all financial, family, local-parent, schema6/archive contracts and SYNC-003/004/009/010.

The bootstrap channel installs a random pair ID and secret in one pending Keychain envelope after explicit approval. Both endpoints then close the bootstrap channel and automatically establish a new channel authenticated with the permanent key. Activation is durable before the test ping/pong/completion exchange. A reopened pending pair can recover via the explicit Sync action. The test has fixed display/scanner roles and one pair, not real device IDs, family/child grants, multiple-peer authorization or revocation. Its random pair ID binds the recovery attempt; it must not be mistaken for a production authority implementation.

The Keychain service is `pennywood.nearby.enrollment-probe.v1`, with nonsynchronizable `WhenUnlockedThisDeviceOnly` items. No family database or production credential is read, migrated or cleared. Forget removes only the local test item. If the host saved an offer but the joiner never received/persisted it, that orphan requires an explicit Forget/re-pair; no financial state exists to reconcile. Later production enrollment still needs its own storage/grant transaction design.

Network parameters opt into peer-to-peer on discovery/listener/connection, require TLS 1.2 and check the AES-128-GCM PSK suite before application data. Discovery is bounded to 60 seconds, initial invitation to 120 seconds, connection attempt to 15 seconds, and exchange inactivity to 30 seconds. Only one connection is admitted at a time. The prototype offers explicit retry; automatic transient retry remains a later production integration detail. Invitation expiry has a monotonic session deadline in addition to its wall-clock hint. Daily discovery uses secret-derived rotating names with one minute of clock-skew tolerance. No router-free claim follows from opting into the API.

Frames have a four-byte big-endian length and a 4 KiB body bound for the small synthetic protocol. Fragmented/coalesced frames, types/versions, attempt nonces, credential shape and legal phase order are checked before use. Unknown business input is never dispatched. Diagnostics contain only result, build, elapsed time, fixed TLS labels and test mode; no secret, pair ID, discovery name, endpoint or camera frame is saved/copied. Cancellation/background clears the invitation and closes owned network objects; saved pending/active test trust remains. Resuming is explicit.

The native baseline passed all 22 optical tests. The first new test run exposed missing Keychain entitlements in the unsigned simulator host and an incorrect test assumption that only the TLS client would report a wrong key. The minimal simulator fix enables ad-hoc signing with an empty development team/profile for native XCTest only; no real certificate or manual entitlement is required. The wrong-key test observes either endpoint's handshake failure and still rejects any authenticated-ready event. Tests also refuse a wrong PSK identity. No checks are skipped.

Local focused validation currently passes 37 native tests, including a real Bonjour/TLS enrollment with isolated Keychain writes and a new transport instance reading the saved pair without an invitation, plus two Flutter entry tests. These are simulator/host facts, not two physical-device results. Final full iPhone/iPad production/restart runs, candidate CI, installation and physical steps are recorded separately below when complete.

The owner reports 5/5 ordinary-condition build 19 full-screen optical trials at about one second; a copied summary confirms in 0.5 seconds. The owner subsequently completed the guided build 20 first-pair flow and reports that both devices displayed test-message completion. This is owner-reported two-device enrollment evidence; no timing/diagnostic summary was supplied. The additional 15 optical trials, full optical/negative matrix, no-scan reconnect, true process restart, permission denial/recovery, background/interruption, and no-common-router/no-internet physical acceptance remain pending.

## Build 21 identity repair

The first hosted candidate passed repository checks and the iPhone job, while the iPad Bonjour enrollment/reopen test failed. A local repeated run reproduced failure on its third iteration before authenticated-ready/admission. A fixed matching identity with bytes `00 01 02 03` after the enrollment context then failed an eight-second real loopback TLS expectation; the separate `ff 80 01 02` case passed. Existing random-input tests had not reliably exercised this condition.

The repair encodes the entire context plus ID as Base64 ASCII immediately before supplying the PSK identity to Network. Both ends still use the same unchanged 32-byte secret, TLS version and cipher requirements. The fixed zero/non-UTF-8 regression passed after the repair, and all 30 repeated wrong-key/identity refusal runs passed. The repeated Bonjour test passed 23 times before one reopened-session timeout near a discovery-name minute transition. Its enrollment had already completed; the cause of that later timeout is unconfirmed. After adding bounded reopened-session stage records, a separate 50-run enrollment/reconnect sequence passed without retries or changed timeouts. This does not prove the intermittent timeout fixed. Keep it as an open acceptance risk; final iPhone/iPad checks and current-candidate CI are separate gates reported on the draft PR.

The native failure reporter now traverses the result tree to retain bounded stage markers that are absent from the first-failure summary, without exporting assertion content or attachments. A nested-marker fixture checks that private assertion values are omitted; the same parser also recovers the marker from the actual failing result tree.

Build 20 was installed on both selected devices, and the owner now reports first enrollment/test-message completion on both ends. Build 21 installation and acceptance remain separate: update both endpoints, preserve that saved pair, then validate no-scan Sync and actual process restart. The Keychain envelope and stored test keys are unchanged, so a valid saved pair can be retried without clearing it. Database schema6, encrypted archives, production credentials and optical encoding remain unchanged. This patch does not establish production security acceptance or any unreported physical trial.

## Sources

- S1: Apple, [TN3213: Moving from Multipeer Connectivity to Network framework](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework). Read 2026-11-08: old/new API distinction, TLS-PSK limits, peer-to-peer opt-in, stop browsing before connection, reliable-stream framing and privacy.
- S2: Apple, [Building a custom peer-to-peer protocol](https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol), including the linked TicTacToe sample archive. Read 2026-11-08, especially `Networking/NWParameters+InitWithPasscode.swift` and `Networking/PeerBrowser.swift`.
- S3: Apple, [sec_protocol_options_add_pre_shared_key](https://developer.apple.com/documentation/security/sec_protocol_options_add_pre_shared_key(_:_:_:)) and [NWParameters.includePeerToPeer](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer); exact signatures additionally checked in the SDK below.
- S4: Apple, [TN3179: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy). Read 2026-11-08: declarations, Bonjour/multicast distinction, `.PolicyDenied` and `.localNetworkDenied` handling, prompt timing and simulator limits.
- S5: Apple, [NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription) and [NSBonjourServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices). Declaration requirements are also stated directly in S4.
- S6: Apple, [TN3151: Choosing the right networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api), peer-to-peer networking and Bonjour sections. Read 2026-11-08.
- S7: Apple, [Use Bluetooth and Wi-Fi in Control Center](https://support.apple.com/en-us/102412). Referenced by the implementation plan; physical trials must record which radio controls were used.
- S8: Apple, [kSecAttrAccessibleWhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly) and [kSecAttrSynchronizable](https://developer.apple.com/documentation/security/ksecattrsynchronizable); accessibility, nonmigration and nonsynchronizable behavior checked directly in `SecItem.h`.
- S9: IETF, [RFC 4279 section 7.1: Perfect Forward Secrecy](https://www.rfc-editor.org/rfc/rfc4279.html#section-7.1) and [RFC 5487: PSK cipher suites with AES-GCM](https://www.rfc-editor.org/rfc/rfc5487.html). Read 2026-11-08. The accepted plan already discloses this limitation; the selected `0x00A8` suite is PSK, not DHE-PSK.
- SDK: Xcode 16.1, iPhoneOS 18.1 SDK, `Network.framework/Modules/Network.swiftmodule/arm64-apple-ios.swiftinterface`; `Security.framework/Headers/SecProtocolOptions.h`, `SecProtocolMetadata.h`, `SecProtocolTypes.h`, `CipherSuite.h` and `SecItem.h`. Inspected 2026-11-08. Typecheck artifacts remain under ignored `work/nearby-enrollment/research/`; no physical runtime conclusion is derived from them.
