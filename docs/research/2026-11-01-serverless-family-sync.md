# Family Synchronization Without a Custom Backend

Accessed 2026-11-01. Technical research/recommendations only: no production code, minimum OS, developer configuration, or CloudKit container was changed. This is an English translation of that research snapshot, not a new online verification.

## Recommendation

Parent iPhone/iPad and child iPad use the same Apple Account. Investigate CloudKit private-database synchronization first; CKShare invitations are unnecessary under this premise. Apple hosting avoids a custom backend/login service, but record mapping, device authorization, conflicts, and state UI still need implementation. iCloud does not automatically synchronize Drift/SQLite.

One Apple Account is one CloudKit user. It does not distinguish parent and child. Implement the parent lock/device authorization, and do not assume Keychain credentials move with the ledger. [S1-S5, S14]

| Method | Custom server | Fit | Project role |
|---|---|---|---|
| CloudKit private database | No; Apple hosted | Same account, internet across locations | Preferred candidate; record-level sync required |
| CKShare | No; Apple hosted | Different accounts later | Deferred |
| Nearby peer connection | No internet server | Both apps open nearby | Optional supplement, not continuous background sync |
| AirDrop / files | No | Manual backup, moving devices, offline handoff | Consistent snapshots, not live sync |

## Source snapshot at research time

[Dependencies](../../pubspec.yaml) had Flutter/Drift/SQLite without a cloud/nearby plugin. [Database](../../lib/data/database.dart) used `NativeDatabase.createInBackground(file)` and schema 2 at that time; current production has since advanced to schema 5. [Authentication](../../lib/data/auth.dart) used local `first_unlock_this_device` Keychain with in-process capabilities. At research time [AppDelegate](../../ios/Runner/AppDelegate.swift) only registered Flutter plugins; a native file channel has since been added, but no CloudKit bridge. The [project](../../ios/Runner.xcodeproj/project.pbxproj) minimum was iOS 13, with no cloud/share/local-network entitlement setup in [Info.plist](../../ios/Runner/Info.plist). A development bundle/team setting never proved cloud capability. These were static observations, not device/cloud validation.

## Same-account private database

Each iCloud user has a private database owned by that user; an eligible signed-in account is required. Apple's sharing example explicitly requires the same Apple Account for private-database sync across devices. [S1,S2]

Keep a local Drift ledger per device for offline use and exchange changes. Distinguish local saved, awaiting upload, remote received, and failed/retry. Local success is not proof that the child's iPad received it. [S4]

Proposed loop: child real-work submission -> saved pending review -> parent receives -> checks -> confirms actual payment -> transactional financial posting/upload -> child receives once -> cash/wish update. Offline submission cannot bypass parent payment.

### Cloud identity is not parent permission

Private-database ownership permits the same cloud user to read/write its contents. A custom `role=parent` field does not create server-side role isolation across devices sharing that identity. [S1]

Proposed app protocol:

1. Parent creates a family and local lock on an initial authorized device.
2. Existing parent device approves a new child/parent device through a short-lived code/QR flow; the new device cannot self-select parent authority.
3. Bind a random stable device ID to protected credentials. Mutable display names are not authorization.
4. A new parent device establishes its own local unlock credential. A child device does not inherit it by sharing the Apple Account.
5. Monetary operations validate business permission, device authorization, operation ID, and state at the receiver/business entry, not only the button.

These are unimplemented application rules, not built-in CloudKit family roles. Local locks/device lists help prevent mistakes but do not resist a modified client under one shared cloud identity. Stronger protection needs parent-signed operations verified by receivers or separate-account sharing boundaries. Do not claim private-database server isolation between these roles.

`ThisDeviceOnly` Keychain items are not synchronized through iCloud Keychain. [S14] Syncing the SQLite ledger does not restore another device's credentials.

### Concurrent parents

Two genuine parent devices can still duplicate offline payment/settlement or conflict on budgets. Last-write-wins balances are insufficient. A first protocol may explicitly designate a primary writer while concurrent parent writes are separately defined; this is a design choice, not a hidden always-online requirement. Every command needs a stable operation ID; receiving Drift transactions check version/state/idempotency. Validate duplicate funding, conflicts, retries, and ordering. CloudKit upload retry is not accounting correctness. [S4]

## Account and restriction boundaries

- No iCloud sign-in: private/shared access is unavailable; constructing a database object proves no permission. Check `accountStatus`, retain local use/pending changes, and report disconnected sync. [S1,S6]
- Apple supports child accounts with regional age rules. Do not claim children universally cannot use CloudKit, or guarantee every sharing configuration. [S7]
- `CKAccountStatus.restricted` can reflect parental controls or MDM. Validate managed/restricted target configurations rather than asserting universal coverage. [S6]
- Account changes are notified by CKSyncEngine; local-data policy remains app responsibility. Never upload an old family's ledger to a new account or silently erase local data. [S4]
- The present family premise is a shared account, so separate child-account invitations are deferred.

## Different accounts: CKShare later

Apple's example uses different accounts: an owner creates a share/link, a participant accepts, and records appear in the participant's shared database. Participants need valid iCloud accounts. [S2,S3]

`UICloudSharingController` manages invitation, leaving/revocation, and read/write choices; it does not generate Drift sync logic. Handle acceptance/revocation/errors/cache explicitly. Set the iPad popover source or risk a runtime exception. [S5]

Family Sharing shares services/capacity while members retain private information; it is not automatic app-record sharing. Cross-account Pennywood needs CKShare or explicit authorization. [S8]

CKShare scopes a custom zone or `CKRecord.parent` hierarchy, not per-field permissions on `familyId`, `childId`, or role. Writable participants can change/delete shared records, with root-deletion ownership limits. [S3] Do not grant the child write access to the entire balance/budget/payment scope and merely hide parent buttons. A future candidate separates read-only authoritative accounting from a writable request scope that parents validate. Shared scope must genuinely match child isolation and permissions.

## Nearby transport and lifecycle

Multipeer Connectivity documents infrastructure Wi-Fi, peer-to-peer Wi-Fi, and Bluetooth personal-area transport, with discovery, sessions, messages/files. [S9] This does not promise user-selectable Bluetooth-only routing or every radio-state combination. Test real permissions, versions, and wireless settings.

The documentation says backgrounding stops advertising/browsing and disconnects sessions. Foreground discovery resumes, but closed sessions need rebuilding. [S9] It fits a visible both-apps-open exchange, not remote/continuous background synchronization. Local network/Bonjour requires appropriate usage/service declarations and denial/retry paths.

At research access time, Apple's framework page marked deprecation and recommended Network; TN3213 described **Xcode 27** deprecation, not immediate removal on old OS versions. [S9,S10] It presents iOS 26 Network APIs while explaining earlier `NWConnection`, `NWListener`, and `NWBrowser` alternatives and optional Apple peer-to-peer Wi-Fi. Select APIs for the actual SDK/minimum OS; do not paste newer examples into Xcode 16.1. Pairing, identity, reconnect, deduplication, and transactional receiving still need implementation.

## AirDrop/files are snapshots

AirDrop requires explicit selection, sharing, reception, and suitable wireless/receive settings, with OS-specific differences. [S11] A versioned export can support backup/migration after ownership/version/integrity checks and parent approval. Later edits do not update an already-sent file.

Never share a live concurrently written SQLite file or treat an iCloud Drive database path as multi-writer sync. SQLite's backup API and `VACUUM INTO` provide consistent independent snapshots. [S12] Preserve local state before import and coordinate writes. Independently modified snapshots cannot merge by adding/replacing balances.

## Flutter / Drift integration

CKSyncEngine requires iOS/iPadOS 17. [S4] The project minimum is 13; choose older CloudKit operations or explicitly decide a minimum increase after checking actual devices. This research did not change it.

CKSyncEngine requires pending record changes, received-event handling, persisted sync state, and application decisions for conflicts such as `serverRecordChanged`. Scheduling depends on system conditions and can be delayed. It neither reads SQLite tables automatically nor checks parent payment permission/conservation. [S4]

Keep Dart business rules/Drift transactions and bridge typed changes/status to Swift Apple APIs through platform channels. [S13] Any third-party plugin needs a maintenance, OS, sharing, conflict, account-change, and error review; none was selected here.

Minimum responsibilities: stable family/child/device/operation IDs; save outgoing status with the operation in one Drift transaction; record-level mapping/cloud versions/cursors; restart-safe receiving with permission/state/version checks; explicit revocation/account/old-version/conflict paths; local-save and cloud-delivery feedback kept separate. Never replace remote accounting with a whole JSON/SQLite snapshot.

## Developer capability, production, and cost

CloudKit setup requires eligible Apple Developer Program membership/permissions, iCloud/CloudKit capabilities, container, signing, and push configuration. [S15] Developer identity is separate from a device's iCloud identity. A simulator build proves none of these cloud steps.

App Store apps use production. Deploy record types/fields/indexes from development; this does not copy test records, and production deletion constraints require migration planning. [S16] Real signing/devices/production still need validation.

No custom server does not mean zero cost/capacity limits/maintenance:

- Standard Developer Program membership is USD 99 per year, with regional differences and eligible organizational waivers; not one membership per child. [S17]
- Private records use the user's iCloud storage. `quotaExceeded` distinguishes developer public quota, current-user private quota, and shared-zone owner's capacity. [S1,S18]
- Handle throttling, connectivity, unavailable accounts/services, and business errors even where CKSyncEngine retries transient failures. [S4]
- Marketing about up to 1 PB public data is neither a private/shared-family entitlement nor a verified overage price. No family-specific excess-cost quote was established. [S19]
- Development, testing, maintenance, and possible user storage upgrades remain costs. No membership purchase/container/cloud deployment occurred during research.

The `sharedCloudDatabase` property page and specific `quotaExceeded` text describe shared capacity differently. Use the specific error guidance for recovery UI, and verify actual container/account capacity before release rather than asserting billing guarantees. [S18,S20]

## Suggested sequence and actual evidence

1. Real same-account two-device private-record round trip, account checks, offline reconnect, different networks.
2. Device approval/local parent lock and independent parent credential recovery; no child self-promotion.
3. Child submits -> parent checks/pays -> child receives once -> restart consistency; duplicate upload/receive cannot double-credit.
4. Multiple parents, both children, finance/withdrawal/repayment conflicts and upgrades; explicitly decide iOS 13 support versus a minimum increase.
5. Consistent manual backup; nearby transfer only if real offline demand justifies it; cross-account sharing later.

This study was static/source research only: no developer-console login, CloudKit/device pairing, restricted-child-account, nearby, or background-runtime validation. API feasibility is not device acceptance.

## Primary sources actually read

Apple bodies were read through official documentation JSON, not search titles alone. Links below point to canonical pages. SQLite and Flutter sources are explicitly identified.

- [S1: privateCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase): account, ownership, quota.
- [S2: Sharing CloudKit Data with Other iCloud Users](https://developer.apple.com/documentation/cloudkit/sharing-cloudkit-data-with-other-icloud-users): same/different-account flow and change/cache examples.
- [S3: CKShare](https://developer.apple.com/documentation/cloudkit/ckshare): zones/hierarchies, participants, permissions, acceptance.
- [S4: CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5): availability, scheduling, persisted state, conflicts, account changes.
- [S5: UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller): sharing management and iPad presentation.
- [S6: CKAccountStatus.restricted](https://developer.apple.com/documentation/cloudkit/ckaccountstatus/restricted): parental controls and MDM; associated account/database pages also read.
- [S7: Create an Apple Account for your child](https://support.apple.com/en-us/102617): regional age and management.
- [S8: Share iCloud+ with your Family Sharing group](https://support.apple.com/en-us/108783): shared services/capacity, private member data.
- [S9: Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity): transport, discovery/session, background, declarations, deprecation.
- [S10: TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework): Network migration, versions, peer-to-peer Wi-Fi; examples not executed.
- [S11: AirDrop on iPhone/iPad](https://support.apple.com/en-us/119857): manual transfer and version differences.
- [S12: SQLite Online Backup API](https://www.sqlite.org/backup.html): consistent snapshots and `VACUUM INTO`, not an Apple sync guarantee.
- [S13: Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels): Dart/Swift/Objective-C bridging.
- [S14: kSecAttrSynchronizable](https://developer.apple.com/documentation/security/ksecattrsynchronizable): synchronization and ThisDeviceOnly; corresponding accessibility documentation also read.
- [S15: Enabling CloudKit](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app) and [Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services): membership, signing, entitlements, container/push.
- [S16: Deploying a Container Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema): environments and schema restrictions.
- [S17: Developer Program enrollment](https://developer.apple.com/programs/enroll/): fee and waivers.
- [S18: CKError.quotaExceeded](https://developer.apple.com/documentation/cloudkit/ckerror/quotaexceeded): capacity responsibility.
- [S19: CloudKit overview](https://developer.apple.com/icloud/cloudkit/): service/container/console and public marketing limits.
- [S20: sharedCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/sharedclouddatabase): access and quota wording.
