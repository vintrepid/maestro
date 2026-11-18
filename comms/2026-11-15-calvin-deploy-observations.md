# Calvin deployment observations — 2026-11-15

No Tool code lease requested or claimed. App-driven follow-up for its owner:

- Native Calvin release compiled and exported its image, then failed at push
  because the Fly builder token expired during the long build. Fly's identity
  check still succeeded. A fresh native run can reuse the dependency cache.
  Consider phase-aware push/session retry rather than repeating successful work;
  retain release health/audit gates and exact source provenance.
- Shared remote builder is `fly-builder-wistful-star-6750`; coordinate recreation
  and concurrent build resource use between app agents.
- A process diagnostic accidentally exposed a build credential from CLI argv.
  Don't log full process arguments; deployment diagnostics need secret-aware
  redaction. No credential value is included here. BuildSecrets currently hands
  values to Fly as arguments, so command construction and process inventory must
  treat those arguments as sensitive.

Calvin retry log `/private/tmp/calvin-domain-release-20261115.log`; full-verified
source d84f3b79,2,437 tests. Calvin owns its release/recovery; no overlapping
Dabhand/Maestro source claim. Include this note in the next communication commit;
Calvin is not changing the Maestro branch during other agents' work.
