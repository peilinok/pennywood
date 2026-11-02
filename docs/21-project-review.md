# Project Review

The first publication review on 2026-11-02 inspected the complete source because there was no earlier local Git history and the remote was empty. It did not compare against an unknown baseline. Independent Standards and Spec reviews followed the code-review workflow, with a separate publication/privacy inspection.

## Standards

One P2 finding, no confirmed P0/P1: `ActionForm` in `lib/features/wish_home.dart` did not observe lifecycle. After revealing a secret and backgrounding/resuming, the secret remained visible. The home parent's lock could not clear a modal's own input state.

`test/credential_visibility_test.dart` first reproduced the failure. The form then registered/unregistered `WidgetsBindingObserver`, cleared secret fields, and concealed them on leaving the foreground while retaining ordinary fields. Regression checks cover the inactive phase and a complete background/resume sequence. Read-only follow-up review found no new defect in this fix. Accounting, schema, and cryptography were unchanged.

Scope included authentication, backup/recovery, Drift transactions, the business entry, monetary settlement, and the iOS file channel. Static review is not proof that no defects exist.

## Spec

One P2: onboarding in `lib/app/screens.dart` said recovery was unavailable despite an existing parent recovery-code feature. Strengthened widget assertions failed first; the hint now explains generating and separately storing a recovery code after setup.

No new provable core-accounting defect was identified in zero onboarding, child scope, check/payment separation, payment-reuse rejection, budget protection, integer interest, or month-end dates. CloudKit remains an explicit unimplemented capability. Docs 08/09 were clarified to separate prototypes, production local behavior, and future sync.

## Publication and language maintenance

Both prototype builders failed in an isolated clean export without `outputs/`; they now create it. The reference accounting verifier also creates its output directory. Generated artifacts remain ignored. No third-party runtime dependency was added.

The personal signing team moved from the project file to ignored `Signing.local.xcconfig`. The public project can build for a simulator without it. Signed packages, logs, device information, ledgers, and old archives remain local. Actual staged blobs, complete reachable history, and commit identities are scanned; see [privacy](22-publication-and-privacy.md).

Repository material and development metadata now use English; the Chinese product UI and business fixtures remain intact. Public document/report paths are ASCII and all links are updated. At the user's request, the two original publication commits are replaced by one English root commit. The old history is backed up only in an ignored local bundle, with no public backup branch/tag. Subsequent commits must use English subjects and bodies.

Both P2 findings are fixed in 0.3.6+10; schema remains 5. See [native validation](10-native-validation.md) for current versus historical evidence. Cloud sync and human VoiceOver remain pending.
