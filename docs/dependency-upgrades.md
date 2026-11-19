# maestro dependency upgrades

Branch: master · Revision: 62f91524ecaefcfae8078210091b0110a4747fb3

Generated from this project's updater records. Updated 2026-11-18T23:51:34.401508Z.

## Updated in the app

| Dependency | Before | After |
|---|---|---|
| ash | 2b35f0740dea | 3ba80ea825a1 |
| ash_authentication | 4.15.1 · 330ea7b02ecc | 4.15.1 · 704afa74b840 |
| ash_money | 0.2.7 | 0.2.8 |
| ash_ri | 275a538e6896 | 208c50957211 |
| bandit | 1.14.1 | 1.15.0 |
| cinder | 019b58d3e5d4 | 43280ff34e85 |
| cldr_utils | 2.29.7 | 2.29.8 |
| ex_money | 6.3.0 | 6.3.1 |
| finch | 0.24.0 | 0.25.0 |
| idna | 7.1.0 | 8.0.0 |
| joken | 2.7.0 | 2.8.0 |
| live_select | 1.5.5 | 1.7.5 |
| live_table | b1809b533440 | ca009633c8c2 |
| localize | 1.7.1 | 1.8.0 |
| playwright | 1.65.0 | 1.65.1 |
| playwright-core | 1.65.0 | 1.65.1 |
| plug | 1.20.3 | 1.20.4 |
| postcss | 8.5.32 | 8.5.33 |
| reactor | 1.0.7 | 1.0.8 |
| source-map-js | 1.2.2 | 1.2.3 |
| swoosh | 1.29.3 | 1.30.0 |
| typo-js | 1.4.0 | 2.0.0 |

## Prepared or published; app pin still pending

None.

## Still needs attention

- **easymde dependency constraints** (3): @types/marked, codemirror, marked. Review these declaring parents' requirements together, resolve compatible versions, then verify. This group does not establish that a new upstream release is required.

<details><summary>Individual package evidence</summary>

- **build-essential**: Installed image version and advisories not checked
- **docker.io/hexpm/elixir**: Image digest and OS freshness not checked
- **git**: Installed image version and advisories not checked
- **ca-certificates**: Installed image version and advisories not checked
- **docker.io/debian**: Image digest and OS freshness not checked
- **libncurses6**: Installed image version and advisories not checked
- **libstdc++6**: Installed image version and advisories not checked
- **locales**: Installed image version and advisories not checked
- **openssl**: Installed image version and advisories not checked
- **docker.io/node**: Image digest and OS freshness not checked
- **@types/marked**: easymde constrains this dependency below 5.0.2; update the declaring parent or review its requirement
- **codemirror**: easymde constrains this dependency below 6.0.2; update the declaring parent or review its requirement
- **marked**: easymde constrains this dependency below 18.2.1; update the declaring parent or review its requirement
- **Fly · maestro-dabhand**: Health checks not confirmed · image and OS freshness not checked

</details>

## Verification

- Project stage: completed. Host update and verification completed
