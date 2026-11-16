# Dabhand release recovered — uploader verification remains open

Dabhand master52fe062a9812cb8be916bce525af13d0692a40fe is deployed and now
published through MaestroTool.Deploy.GitWorkflow after every configured hook
passed. Durable CatalogPromotion job01a1e1e8-7212-7b2c-ae9c-c184692e9a36 is ready:
8,237 songs,2,841 CLAP artifacts,27 published audio files, catalog proof hash
7b1972a074a52494876b4bc445ec4356e79ceb505cbb6e7651877c3c3a0dd3c4.
Content2801/2440, Vary3/13/90, travel216/6/9, pinned inference, public native
HTTPS upload/FLAC/CLAP/cleanup, email and site hooks all passed. Fresh public
HTTPS and two live health probes since release show1/1 web machines passing.

Canonical MaestroTool uploader/GitSafety source remains frozen during the
complete gate, session36511, log/private/tmp/maestro-fly-upload-isolated-tests-gate.log.
Command: ERL_FLAGS='+S4:4 +sbwt none +sbwtdcpu none +sbwtdio none'
mix precommit --max-cases1 --timeout120000. Keep whitespace between flag and value
when running. No assertions were removed. Explicit CodeReview ten-second limit
is retained; real Git fixtures get120seconds. Previous runs failed under host
load, not accepted as passing. Runtime chunk recovery itself passed for both
63MB content and64MB music with independent full-file SHA checks.
Do not change this source or adopt an unpublished revision. Dabhand owns final
library publication and explicit consumer adoption after full verification.

Dabhand8c2ac2f independently fixes stale promoted podcast capture claims and
all-episode target growth:13 focused checks pass, browser catalog healthy.
Scheduled/backfill actions reconcile actual owned TranscriptVersions before
trusting report counters. Full app gate/deployment of that follow-up pending
verified shared tool adoption. All-song excerpt CLAP is still unfinished;
233 current transcripts and263 indexed episodes do not mean all clips encoded.
A small offline Vosk probe bracketed one supported excerpt from seven minutes;
no prototype paths/models are deployed and no song embeddings were published.
TagAsh remains an explicit scope note, not an ontology implementation.
