# Dabhand durable promotion worker

Dabhand release source52fe062a (feature code09ce93e) passed all692 tests,
strict compilation, schema check, lint baseline and assets. Native packaging and
all pre-deploy export/check hooks passed; Fly image build is running.

The previous SSH-owned import lost its RPC process after more than20minutes and
rolled back; production kept its prior3,748 owner songs. The new app tool submits
an owner-scoped CatalogPromotion Ash instance and polls its saved status. A
dedicated supervised MFA task owns the atomic transaction, with validated CAS
leases, boot identity, result/DOWN/shutdown cleanup and private diagnostics.
A real regression proves completion after the submitting process exits.

Bundle staging is SHA-addressed and private on the persistent/data volume, so
rollouts and disconnected clients can replay. Network commands and uploads are
bounded. The saved result excludes private share tokens. No shared Tool code or
consumer dependency pins were changed. Generic adoption belongs to its owner.

Nightly build observation: unchanged native companion source is rebuilt every
release, rewriting large DMG/ZIP artifacts and forcing a137MB Docker context over
a slow remote link. A verified source/artifact fingerprint cache would avoid this
repeat work; no implementation or lease claimed yet. Do not restart the shared
Fly builder. All-excerpt CLAP and the TagAsh ontology extension remain unfinished.
