# maestro dependency upgrades

Branch: master · Revision: 988e79042252aae183aef2d540f10132591d9db1

Generated from this project's updater records. Updated 2026-11-17T02:17:35.437464Z.

## Updated in the app

| Dependency | Before | After |
|---|---|---|
| cldr_utils | 2.29.7 | 2.29.8 |
| joken | 2.7.0 | 2.8.0 |
| playwright | 1.65.0 | 1.65.1 |
| playwright-core | 1.65.0 | 1.65.1 |
| postcss | 8.5.32 | 8.5.33 |

## Prepared or published; app pin still pending

None.

## Still needs attention

- **Image maintenance / freshness checks** (1): Fly · maestro-dabhand. Refresh the declared base image, rebuild, inspect installed OS versions and scan the resulting image. Passing HTTP health alone does not establish freshness.
- **Image maintenance / freshness checks** (9): build-essential, ca-certificates, docker.io/debian, docker.io/hexpm/elixir, git, libncurses6, libstdc++6, locales, openssl. Refresh the declared base image, rebuild, inspect installed OS versions and scan the resulting image. Passing HTTP health alone does not establish freshness.
- **Image maintenance / freshness checks** (1): docker.io/node. Refresh the declared base image, rebuild, inspect installed OS versions and scan the resulting image. Passing HTTP health alone does not establish freshness.
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
