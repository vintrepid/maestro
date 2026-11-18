# Dabhand shared observability and release recovery claim

Owner: Dabhand Codex /root. User explicitly requests repairing all accumulated app/tool mistakes and deploying. Canonical Tool checkout remains /Users/vince/dev/maestro/vendor/maestro_tool on existing shared branch feature/maestro-tool/elixir-architecture-audit-20261115, base0bfb76b. No branch switch and no overlap with dependency/security producer work.

Claim: new shared observability capture/context/logger/Plug adapters and incident workflow APIs; deploy-stage checkpoint/resume and Fly upload safe diagnostics/compression where required; focused library tests. Existing application boundary remains configurable: OTP app/repo/identity, expected failures, authorization, notifier and routes. Reuse open-source ErrorTracker, do not copy Calvin's legacy second store. Producer focused/full verification and publication before explicit Dabhand adoption. Calvin's source and dependencies stay frozen; read-only reference only until an acknowledged handoff. No email sending via agent tools, no secret logging, no unpublished Solid/distribution adoption or publication workaround.

Dabhand current branch feature/dabhand/destination-aware-playlists-20261117 at78f1c9f; source81d8255 full verification starting in a disposable clone with isolated build/deps/database partition and pinned Tool0bfb76b/Kiaoroc13ba36c. Previous production sourcef47b82b is fully deployed/published, all hooks/audits recovered. New work includes explicit local/provider eligibility and private inventory/location reconciliation. Production has only1GB audio volume versus24.8GB dev files; metadata/location sync and private file replication are separate from public playlist promotion.


## Published handoff

- Shared Maestro Tool revision: `d3a723bfc47ae2b9361b055236a300f27dd57c28`, published on `feature/maestro-tool/elixir-architecture-audit-20261115`. Complete `mix precommit`: 1,088 passed, 8 skipped. No canonical checkout switch or Calvin source edit.
- Automatic approval review rejected updating shared `master`. Consumers can pin the published revision; do not bypass that rejection by another default-branch publishing path.
- Host contract: `docs/shared-error-handling.md` in the library. Preserve app-specific authorization and user messaging. Dab Hand adds a tiny native context filter calling shared `ErrorReporter.context/2` and a Bandit closed-connection filter. The native filter must be configured for direct/native tracker integrations too.
- `Incidents` supports upstream ErrorTracker 0.9.0 via occurrence context and Calvin's existing environment column. Do not copy a second incident database. Native recurrence reopens resolved incidents.
- Reporter queue exposes draining and delivery-failure health. Capture is bounded/supervised/in-memory, not a durable crash spool. Original runtime logs remain essential.
- Release receipts verify source revision, hook plan and deployed image before resuming unfinished hooks with `mix maestro.deploy --resume`. Audits run again. Upload exhaustion now identifies the chunk, checksum, byte count, attempts and phase/status without retaining raw transport output.
- Dab Hand source `bae059b`, gate receipt `856d5fa`: complete app `mix precommit` 731 passed; authenticated local route audit all 200, reporter configured and drained. Deployment running through the normal tool, log `/private/tmp/dabhand-repair-deploy-20261117.log`.
- Private audio inventory metadata now promotes separately from selected public audio bytes. Physical site presence is checked independently from sample/full extent and CLAP. Production-only data and public audio allowlists are preserved. No bulk audio-byte copy or Pandora publisher was added.
- Calvin remains frozen/read-only under its existing release owner. Adoption there remains that owner's explicit integration step.


### Deploy preflight correction

The first Dab Hand deploy stopped before build because publication checks used
stale local remote-tracking refs. A detached exact-SHA fetch had not advanced the
feature-branch cache. `187c7c566e60f1f15869e55b81207eec591d95f1` now refreshes
origin head evidence before publication decisions. Real Git fixtures prove a
published detached pin is accepted and a genuinely unpublished one still blocks.
The existing keep-branch flag consistently skips unrelated cleanup too.

Exact shared full `mix precommit`: 1,090 passed, 8 skipped, log
`/private/tmp/maestro-submodule-final-gate.log`. Exact consumer full gate: 731
passed, `/private/tmp/dabhand-final-inventory-gate.log`. Consumer source `e7dcbd6`
is in the normal master integration/deploy workflow now; retry log is
`/private/tmp/dabhand-repair-deploy-retry-20261117.log`. Shared master remains
unchanged under the automatic-review rejection. This is a published feature pin,
not an unpublished producer change or a default-branch publishing workaround.

## Repair follow-up, 2026-11-17

Dab Hand first release `8073c55f9b2c2eb1c70feb455c15f3441e30e5af` is deployed, all nine post-hooks and enforced authenticated runtime/error audit passed. Production has 1,797 audio inventory records and 117 physical files; all 117 original files retain their exact bytes and SHA256. No bulk private audio transfer or public allowlist widening.

Follow-up consumer commit `ff98c27` pins published Maestro Tool `3d96b7bccbb65a23823e120e00a59887162f5cba`, including our `11ad816` compressed bounded-parallel Fly upload. Eight focused uploader checks passed. Exact shared complete gate is running in immutable `/private/tmp/maestro-upload-11ad816-verification`, separate build/deps, `mix precommit --max-cases 1`, log `/private/tmp/maestro-3d96b7b-serial-gate.log`; existing timeouts unchanged. Prior default-concurrency fixture I/O timeouts reproduced passing individually, retained here as evidence rather than ignored.

Consumer follow-up complete gate passed: 735 tests, strict compile, no new lint, assets. Known decoder rejections now skip playback/checkpoint restoration and get a durable full-audio request. Model-analysis uncertainty remains independent from audio readability. Release submission now creates/reuses only the minimal CatalogPromotion identity and retries lost acknowledgements; its worker owns staged payload validation/import. The flaky Cinder sort wiring assertion was removed under the user's unit-test guidance; subscription persistence and ownership coverage remain.

Shared master publication and resolving the old local closed-connection incident remain held after automatic review rejection. Published feature revision is the safe pinned consumer path. No Calvin checkout changes.

## Final production verification

Dab Hand source `a686a4c4c6bee2b9ad46dc44523e26a5824e64d4` is deployed and published on master. Image `registry.fly.io/dabhand:maestro-1794923397573`. Standard `mix maestro.deploy --app dabhand --require-clean --yes --keep-branch` exited 0; all nine post-hooks and enforced authenticated route/error audit passed; receipt is ready. Public native HTTPS upload, lossless FLAC return, CLAP vector and cleanup verified. Music promotion resource `01a1e9d4-eeee-7475-9e8e-fd9c91fc0e1d` ready: 8,583 songs, 2,850 CLAP artifacts. Private inventory known audio 1,797; 117 files here; all 117 original files retain byte counts and actual SHA256. The 27 published files remain a selected subset.

Exact shared complete gate `3d96b7b`: 1,109 passed (1 doctest + 1,108 tests), eight existing skips, exit 0. Consumer complete gate and deployment test pass: 735 passed. Final private handoff `/Users/vince/dev/dabhand/.local/maestro/deploy/dabhand-repair-final-handoff.json`. Source tree clean. Shared default-branch and old local-incident resolution restrictions remain as recorded above.

Performance observation retained: first post-cutover music pages took 8-20 seconds; warm route audit took 2-6 seconds; focused warm CD request 1,402ms. Do not claim cold-load latency solved. The new successful Ash tracer path only records process-local metadata; source/error work happens on failures. No additional source patch was made after the deployed revision.
