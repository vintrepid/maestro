# Dabhand music release and ontology work

Owner: Dabhand agent. Existing checkout and branch retained; base at check-in
8ed9e730e2f1ea7bb977b4c7f76205d9a783042f. Vince authorizes staged deployments,
all 500Songs episodes/samples, then catalog-wide enrichment and another deploy.

Claim: Dabhand music/search resources, ResearchAsh bounded HTTP range adapter,
media/transcript alignment and tests. No Calvin source or Maestro Tool code claim.
Read Calvin task15323 handoff; reuse SourceRunner and resource-owned checkpoints,
retry windows, provenance and bounded independent processes. Coordination goes
through existing WIP branches/comms, with selective commits and no branch switches.

Current truth: 50 targeted transcripts ingested; 3,091 named references linked;
26 referenced songs already have CLAP. Three newly encoded episode windows are
unassigned samples, not identified song excerpts. Alignment remains unfinished.
2,045 songs have explicitly contextual genre candidates and episode citations.
13 focused checks pass; no new lint. No deployment yet. Existing FestivalArtist
cross-owner acceptance test blocks release; explicit policy-edit approval requested.

Next: expand durable backlog to all episodes; add identity-safe sample alignment,
then enable source/catalog enrichment through model actions. AshTags ontology
extension needs concept IDs, lexical aliases, typed relations, evidence and
versioned mappings to app resources; synonyms are not automatically owl:sameAs.
Maestro owner: please coordinate shared AshTags ontology capability/interface
before overlapping edits; no library code lease claimed by Dabhand.

Coordination commit in Dabhand: 0b1600b. This commit changes communication only.

## Deployment and alignment update

Dabhand page compile error is corrected and browser verified. Vince explicitly
approved the FestivalArtist ownership fix and all staged deploys; no approval
question remains. Resource ownership acceptance now passes. Full app test hook:
683 passed. Current integration image source9030248 includes all accumulated
music/search work; no production success claimed yet. Depot upload failed with
invalid-token health reports; retry uses the existing --no-depot option.

Consumer Maestro Tool doc-only commitf0ad3a0 is published on
docs/dabhand-crawler-handoff-20261115; runtime library code is unchanged.

All-episode crawl captured233 transcripts from263 indexed entries;30 report
transcript_not_published (pledge/bonus/introduction entries retained). Daily page
budget500, sample budget12. No global catalog sweep enabled before first deploy.

ASR capability probe uses existing local torch/transformers plus public Whisper
tiny.en weights. Word timestamps work, but exact anchors around a real excerpt
were missing; no fabricated song alignment. Next implementation must retain
model/input identity, distinguish intro music, checkpoint episode media spans,
and isolate ASR/CLAP work with cancellation/timeout/claim cleanup.

Maestro coordination request: review docs/music-ontology.md in Dabhand for the
shared TagAsh vocabulary/assertion contract before parallel library edits. No
TagAsh or Maestro Tool code lease claimed by Dabhand.
