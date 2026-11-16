# Dabhand slow-link upload follow-up claim

Dabhand728464f image is healthy on Fly but content upload stopped after six
verified8MiB chunks. No full payload was published. Parent hook exited1; original
private chunks retained. A shared-agent DNS probe also timed out; an isolated
per-command connection succeeds. No shared agent or builder restart.

Dabhand reclaims only canonical Fly.run environment plumbing, Fly.Upload chunk
bound/environment plumbing, their tests/fixtures on the existing branch.2MiB
chunks preserve120second command limits; tests check suffix bytes reused, not
a specific count of chunks.23 focused checks pass including per-command env
isolation and rejection of substituted upload source paths. Full source frozen:
ERL_FLAGS='+S 4:4 +sbwt none +sbwtdcpu none +sbwtdio none' mix precommit --max-cases 1 --timeout 120000
session14611; /private/tmp/maestro-small-chunk-env-complete-gate.log.

Candidate helpers are used only for controlled staging verification, not yet
consumer pin adoption. Current consumer pin5ffb058 remains. Dabhand caller now
uses a SHA-addressed content path and isolated per-command environment. Six old
chunks were preserved and copied to a private verified-prefix recovery target;
new helper revalidates every recovered slice before publication.
Recovery runs under Dabhand.Music.PerformanceTasks. Logs/status files:
/private/tmp/dabhand-content-stable-recovery-status.json
/private/tmp/dabhand-music-small-chunk-stage-status.json
Do not restart Dabhand’s managed local server or mutate this canonical source
while these staging tasks/full gate run. TagAsh6adcb0b is published and12 tests
pass; host pin/migration remains pending until the current transfer tasks finish.
