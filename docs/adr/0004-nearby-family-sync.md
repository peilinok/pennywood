# 0004: Nearby synchronization with one primary accounting device

Status: Accepted product direction; implementation and validation pending
Date: 2026-11-06
Feature IDs: SYNC-003 through SYNC-009; preserve all local contracts
Decision owner and approval reference: The owner approved one-time Apple-inspired visual pairing followed by automatic Wi-Fi synchronization when both ends tap Sync. In the same planning conversation, the owner selected one primary accounting device, with other devices submitting requests or viewing data.

## Context

Current production data is local Drift storage. Parent and child areas on one device share a ledger; different devices do not synchronize. The earlier same-Apple-Account CloudKit route is a researched candidate, not an implemented dependency. The owner wants nearby collaboration without routine rescanning, manual Wi-Fi switching or a required shared Apple Account.

## Options

- CloudKit first: supports remote exchange but requires cloud identity/configuration and a separate authorization/conflict protocol. Retain as future research.
- Nearby Wi-Fi through Network: supports a deliberate foreground exchange and larger initial history, with device trust managed by Pennywood. Chosen for the first implementation.
- BLE or acoustic transport: possible alternatives, but additional protocols/permissions and device testing are not justified for the agreed first path. Deferred.

## Decision

- Use a branded, soft particle/dot visual code for first-time camera pairing. Preserve an actually decodable payload and reduced-motion alternative. Apple visuals are inspiration, not an Apple-compatible account protocol.
- After pairing, both users tap Sync. Discover and authenticate the stored peer automatically. Reconnects do not require another scan, chooser or ordinary manual Wi-Fi switch.
- Investigate the iOS13-compatible Network APIs with Bonjour and Apple peer-to-peer Wi-Fi. Keep the existing iPhone/iPad platform scope and deployment minimum unless a later explicit decision changes them.
- Exactly one primary device commits canonical financial state and authorizes peers. Companions submit permitted child intents or view explicitly granted children. They cannot confirm payment or become a primary through a shared passcode or sync key.
- Preserve existing local parent/child use on the primary. Companion balances reflect confirmed state; pending intents never masquerade as posted money. Parent check and actual payment remain separate.
- Use bounded foreground sessions. The primary is not required to be permanently online. Offline requests remain durable until the next nearby exchange.
- Defer CloudKit, independent financial writers, BLE fallback, acoustic transfer, automatic election and background-always-on behavior. Existing SYNC-001/002 remain historical future contracts; SYNC-003 through SYNC-009 describe this delivery route.

## Consequences

The first release cannot synchronize across distant locations. Users can read their last confirmed state and save allowed requests offline. The primary remains necessary for confirmed financial changes. Pairing must enforce child scope and durable device identity independently of local parent unlock.

The implementation must prevent replica date catch-up, preserve original task/holding promises, order requests, record deduplication outcomes and recover interrupted transactions. A styled visual code is not sufficient device security or evidence of camera reliability. A disconnected old primary cannot be globally fenced without coordination; replacement/recovery must explicitly retire the former copy and disclose lost intervals.

## Validation and recovery

The [implementation plan](../28-nearby-family-sync-plan.md) defines modules, protocol, proposed migrations/archives, failure behavior, stages and acceptance. Its engineering details are reviewable proposals; this ADR does not assert that a TLS choice, QR styling or radio combination has passed.

Start with synthetic two-device discovery/authentication and camera proof, then implement one complete child-submit/parent-pay/child-receive loop before expanding coverage. Preserve all existing accounting, permission, migration and recovery tests. Keep actual physical acceptance distinct from simulator/reference evidence.

This documentation decision changes no current binary, schema6 database, archive reader or credential. A future schema change needs its own migration/backup evidence. No merge or distribution authorization is implied.
