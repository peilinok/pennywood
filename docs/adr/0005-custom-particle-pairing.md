# 0005: Custom particle optical pairing

Status: Accepted product direction; format and native recognition pending
Date: 2026-11-06
Feature IDs: SYNC-003, SYNC-009, SYNC-010, AUTH-001, AUTH-002
Decision owner and approval reference: After seeing the branded standard-QR preview with three finder boxes, the owner explicitly requested custom visual encoding and recognition.

## Context

The first implementation-plan draft used a standard QR matrix surrounded by decorative particles. Its three locator boxes remained visible, so the owner chose a fully custom particle field. This refines the optical realization of [ADR 0004](0004-nearby-family-sync.md); it does not replace its single-primary, nearby Wi-Fi or one-time-pairing decisions.

## Options

- Keep a styled QR and use the platform barcode decoder: lower recognition work, but not the requested visual result. Rejected for this flow.
- Display an ornamental particle sphere while transporting the enrollment secret elsewhere: would not meet the request for actual visual encoding/recognition. Rejected.
- Encode a short enrollment payload in a custom circular particle layout and implement its own recognition: chosen, with explicit native/device gates before release.

## Decision

Use a real custom optical payload, fixed data dots and integrated round locator constellations, with no square QR or QR finder boxes. Encode enough high-entropy information for the already planned enrollment handshake; leave actual data synchronization on Network. Keep the payload and locator geometry stationary while decorative particles animate outside protected regions. A reduced-motion static image must still work.

The proposed PWPC v1 experiment uses a fixed 64-byte payload, RS(96,64) error correction and position-coded particles. These concrete format parameters are candidates to validate and version, not accepted reliability claims. AVFoundation supplies camera frames; the app implements custom localization and decoding. No standard barcode API is assumed to recognize PWPC.

A decoded code is not an authorized device. Preserve short-lived single-use enrollment, parent scope approval, network authentication, durable activation, revocation and the security caveats of the transport design. Camera failure does not silently switch back to the rejected QR appearance.

## Consequences

Custom recognition adds optical-format maintenance, native image-processing work, performance/energy testing and a larger physical-device acceptance matrix. Synthetic images cannot establish screen-to-camera reliability or false-positive rates. No Apple private pairing format is implemented or claimed compatible.

## Validation and recovery

The [optical specification](../29-particle-pairing-code.md) defines the experiment, recognition pipeline, limits and N1a/N1b gates. If device acceptance fails, keep production local-only and revise this format before enabling pairing. No current app code, schema, archive, credentials or platform minimum is changed by this documentation decision. Merge and distribution remain separately authorized actions.
