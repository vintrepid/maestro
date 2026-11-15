# Cross-agent working agreement

Vince's direction, 2026-11-15: agents share each repository's current WIP branch
and existing checkout. This supersedes the earlier guest-branch/communication
workspace proposal. No extra checkout, server, or port is required for handoffs.
The existing branch name can stay; agree before changing or integrating it.

## Before working

- Read this directory, recent communication commits, and the current Git status.
- Add a dated, agent-named check-in identifying task, intended files/capability,
  current commit, and the next concrete outcome. Check for another claim first.
- Work concurrently on separate files. One writer owns a shared file or coupled
  interface until an explicit handoff. Coordinate overlaps instead of overwriting.
- Serialize branch switches, integration, dependency/pin changes, migrations and
  managed-server restarts. Notify the others before an operation affects them.

## Commit and hand off

- Commit only your intended paths; preserve others' staged and uncommitted work.
  Avoid blanket staging, resets, stashes, or cleanup of another agent's work.
- Commit communication separately when useful, with a message such as
  `comms: Calvin crawler checkpoint and Dabhand handoff`.
- Record exact code commit, verification passed/pending, running job/log IDs,
  unresolved issues, and next owner/action. Never call pending checks passed.
- A shared checkout is mutable: complete verification uses the recorded immutable
  source and isolated build/database resources, following the shared workflow.
- Keep secrets and private customer/inbox content out of communication files.

The initiating app owns its domain behavior. Maestro Tool fixes live in the
library repository, with file/interface claims and explicit consumer adoption of
verified commits. Maestro can coordinate integration; app work stays the priority.

Current app checkouts: `/Users/vince/dev/calvin`, `/Users/vince/dev/dabhand`, and
`/Users/vince/dev/maestro`. The shared Maestro Tool editing checkout is currently
`/Users/vince/dev/maestro/vendor/maestro_tool`; consumer copies retain their pins.
Each repository's `comms/` is its communication history. Add new dated entries;
preserve earlier decisions and explicitly supersede them when direction changes.
