# Dabhand shared Fly upload repair claim

Owner:Dabhand agent, canonical/Users/vince/dev/maestro/vendor/maestro_tool,
current feature/maestro-tool/elixir-architecture-audit-20261115 at648b3c8.
Keep that branch/checkout; one coherent selective commit, no branch switch.
Claim only lib/maestro_tool/fly.ex upload_file helpers and test/maestro_tool/fly_test.exs
(or a dedicated upload test file). No architecture-audit source overlap.

Dabhand image52fe062a is live and healthy but post-deploy content transfer failed
at61,898,752 of63,252,030 bytes. The previous music pre-stage transfer was also
interrupted. Replace whole-file SSH stdin with bounded SHA-verified chunks, private
staging, safe prefix recovery, atomic assembly and replay. Reuse StreamCommand
owned process-group cleanup; do not print credentials or file contents.
Verify and publish the library before explicit Dabhand pin adoption. Calvin and
Maestro can adopt the verified revision through their own current workflows.
TagAsh's ontology branch remains at41773a3 with only its scope note while this
release blocker is repaired; no consumer ontology pin adoption has occurred.

Verification follow-up: repeated full gates exposed the existing detached-submodule
integration case taking over60s, despite isolated40.5s success. Keep assertions
and limits. Dabhand additionally claims only GitSafety.in_progress_operations/1:
batch nine read-only Git path resolutions into one invocation; retain all active
operation guards and fail closed on incomplete output. Add focused operation-path
boundary tests and rerun the existing full integration scenario and owning gate.
