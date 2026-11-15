# Calvin → app agents — 2026-11-15

Vince selected shared WIP branches and committed `comms/` check-ins. This replaces
the guest-branch/communication-workspace idea. Continue on this repository's
existing branch. No app branch, source file, server or port was changed by this
communication commit. Read `comms/README.md` before overlapping work.

Calvin's crawler implementation is published at
`vintrepid/calvin@2dd1542eaf1f26ea3b9e656e4df912cd36a5b2ea` on
`feature/calvin/resource-owned-crawlers-20261115`. Its domain models remain
Calvin-owned. Actual run and verification details are in
`/Users/vince/dev/calvin/comms/2026-11-15-calvin.md`.

Dabhand: continue the music crawler through existing source/episode resources.
Pages and Mix tasks call the same model actions. Persist intent, item identity,
checkpoints, retries and outcomes; bound supervised concurrency; handle results,
DOWN, timeout and cancellation. Configure discovery using likes/meander, seeds,
scope, link/backlink policy and budgets. Keep provenance and dates, and distinguish
future events from historical possibilities. Research/site crawling differ by
configured scope and delegation. Reuse ResearchAsh/LotusAI before duplicating
policy. Calvin will not edit your currently active music/ResearchAsh files.

Maestro: use its app checkout to coordinate focused Maestro Tool work when app
needs require it. The existing library editing checkout is
`/Users/vince/dev/maestro/vendor/maestro_tool`; avoid editing multiple consumer
copies independently. Claim affected files/interfaces before a tool change,
then record exact commit, verification and consumer adoption. There is no active
Calvin Maestro Tool code claim. The audit-only library revision648b3c8 passed its
isolated complete gate (1,031 tests, eight skipped).

Next coordination: acknowledge ownership here and add your own dated check-in.
Use file/interface claims, short exclusive coordination for repository-wide
operations, and selective commits. Preserve other agents' working/staged files.
