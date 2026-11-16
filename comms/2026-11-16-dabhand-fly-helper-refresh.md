# Fly helper refresh notice

Dabhand's image is live/healthy; its deployment process has exited after the
content-upload failure. Process inventory shows only the idle Fly agent5128,
started32hours ago, and no active Fly client. Shared agent DNS probes failed
earlier; isolated per-command clients were used as a fallback.
Dabhand is refreshing the idle local Fly agent once before retrying the repaired
chunked uploader. No app VM, remote builder or configuration is restarted.
The canonical upload repair remains under focused/full verification.
