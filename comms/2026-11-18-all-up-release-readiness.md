# Calvin agent — merged three-app release readiness

Task15326 owns this integration. Vince requested merging the accumulated branches and preparing the whole release after all-up, before further command/API redesign. All local/origin app branch tips are retained on master, no stashes remain, and no work was discarded.

Verified executable source commits:

- Calvin749234a280f0b0b2a9f5f547e0adfb525b75f7a3:2448passed, `/private/tmp/calvin-final-new-ash-upstream.log`.
- Dabhand1755f3748def46969fdae357c8b51e2f9d04e11b:787passed, `/private/tmp/dabhand-tracer-final-full.log`.
- Maestro8c654e896858b789c1f30c3cefac33632b745e0d:67passed, `/private/tmp/maestro-tracer-bootstrap-final.log`.
- All apps consume Maestro Tool57bd89863141292ad8baed1918877ae8199e0419:1133passed,8existing skips, `/private/tmp/maestro-final-merged-master-full.log`.

App commits include their final generated reports and successful project-update receipts. Communication follow-ups change documentation only. Final Ash73b2402256c65620e12782c106311f4ee71c0c57 passed5198; AshLotuse964ef72032dd10de3f59bca2ef72ce9eddd787d passed34 plus one consumer fixture. Tool's narrow owned-library fast-forward repair retains exact published SHAs and avoids new identical-tree merge commits. No broader VM code-path or remote-tracking rewrite was applied.

All three fresh resource-owned completion checks succeeded at00:37UTC November19: zero pending package updates and zero failed package checks. `priv/dependencies/last_update.json` is now packaged in each app. Maestro's EasyMDE transitive @types/marked, codemirror and marked are at their supported parent-compatible versions; newer incompatible majors are informational, not failed updates. Image/OS coverage remains separate.

After all compilation and inspection jobs finished, Maestro's clean managed stop/start passed its startup settling period, PID49357, `/private/tmp/maestro-final-clean-start.log`. The earlier Repo background-job errors remain in the previous server log and are not a current startup failure. Calvin and Dabhand managed servers also respond normally; Calvin's dependency UI shows all package tabs0.

No production deployment occurred during this readiness pass. Task15326 remains in progress for the standard `mix maestro.deploy` workflows, actual Linux image builds, production migrations/hooks, public-page/MCP/vector verification, and production dependency-report refresh. Do not describe development receipts as proof that the older production image has already changed. Maestro app redesign remains low priority; shared Maestro Tool supports active app work as needed.
