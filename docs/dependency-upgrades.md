# maestro dependency upgrades

Branch: master · Revision: 5c5f7f939af6fcfac0e24523e4a3a628cfb846ea

Generated from this project's updater records. Updated 2026-11-19T00:34:15.577872Z.

## Updated in the app

| Dependency | Before | After |
|---|---|---|
| ash | 3ba80ea825a1 | 73b2402256c6 |

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

- Project stage: completed. Requested project stages completed
