# Curated Repo Skills

Candidates, not a bundle. Recheck exact names with `skills add <source> --list`
and inspect current instructions before installing. Reuse installed skills
before fetching another copy. No candidate overrides repository policy.

## Baseline

| Skill | Source | Boundary |
|---|---|---|
| `ponytail` | [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail), select only `ponytail` | Smallest complete change, scoped checks, explicit omissions. Do not install its audit/review/help bundle by default or activate its session mode merely by installing. |
| `git-commit` | [github/awesome-copilot](https://github.com/github/awesome-copilot), select only `git-commit`; confirm the current name with `--list` | No bundled copy remains here. Commits only when requested; repository conventions and safety win. Do not add a second commit skill. |

## Stack and task candidates

| Evidence / need | Skill and source | Select only when |
|---|---|---|
| React web or Next.js | `vercel-react-best-practices` from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | React web is an actual target. Performance recommendations are not permission to add SWR, caches, or a framework migration. |
| Requested React web transitions | `vercel-react-view-transitions` from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Versions, framework configuration, browser support, and reduced-motion behavior support the requested feature. Upstream currently uses React's experimental API outside Next.js; never auto-upgrade to canary or animate unrelated flows. |
| React Native mobile | `vercel-react-native-skills` from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Native is an actual target. Existing libraries and accepted design constrain Expo-image, FlashList, navigation, and animation suggestions. Web React skills are not an automatic companion. |
| Expo/EAS | Selected skills from [expo/skills](https://github.com/expo/skills) | Match the task: `expo-dev-client` for development builds; currently `expo-upgrade` for an approved SDK upgrade, `eas-app-stores` for release preparation. Inspect current shared/router requirements before selecting. Do not install the entire plugin or run builds/submissions from setup. |
| Browser automation / UI verification | `agent-browser` from [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | No adequate primary browser workflow already exists. CLI/browser runtime setup is separate; current skill content may be served by the installed CLI. This does not replace committed E2E tests. |
| Supabase SDK, auth, storage, platform operations | `supabase` from [supabase/agent-skills](https://github.com/supabase/agent-skills) | Actual Supabase usage and relevant work. Confirm local/staging/production targets; no credentials, MCP configuration, direct SQL, schema changes, or deployments just to install guidance. |
| PostgreSQL schema, SQL, RLS, query performance | `supabase-postgres-best-practices` from [supabase/agent-skills](https://github.com/supabase/agent-skills) | PostgreSQL work, even outside hosted Supabase. If also selecting `supabase`, explain the SQL-versus-platform boundary; do not automatically add both. |
| Web UI/accessibility review | `web-design-guidelines` from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | A concrete UI review need. This checks implementation, not Harness docs. Its remote guideline fetch is not a substitute for accessibility tests or agreed design. |
| Module/interface design | `codebase-design` from [mattpocock/skills](https://github.com/mattpocock/skills) | A real design/refactor decision; no bundled copy remains here, so list the source before installing. Do not layer a second copy or install the source's planning/orchestration suite. |
| Explicit terse-chat preference | `caveman` from [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman), select only `caveman` | User opts into the voice. It is not needed alongside ponytail by default; never rewrite specs, commit messages, or evidence into a terse chat dialect. Do not add caveman commit/review/orchestration variants. |

## Evidence snapshot

Research on 2026-10-12 used skills.sh/Skills CLI search, GitHub repository
metadata, and upstream `SKILL.md` content. Counts are provider-reported adoption
signals, not independent users, audits, or a promise of conflict-free behavior.
Refresh only selected sources when making an installation decision.

| Skill | Reported installs | Source repo stars |
|---|---:|---:|
| [ponytail](https://skills.sh/dietrichgebert/ponytail/ponytail) | 81.7K | 161,223 |
| [vercel-react-best-practices](https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices) | 789.1K | 32,251 |
| [vercel-react-view-transitions](https://skills.sh/vercel-labs/agent-skills/vercel-react-view-transitions) | 149.4K | 32,251 |
| [vercel-react-native-skills](https://skills.sh/vercel-labs/agent-skills/vercel-react-native-skills) | 237.4K | 32,251 |
| [agent-browser](https://skills.sh/vercel-labs/agent-browser/agent-browser) | 1M | 43,832 |
| [supabase](https://skills.sh/supabase/agent-skills/supabase) | 320.4K | 2,766 |
| [supabase-postgres-best-practices](https://skills.sh/supabase/agent-skills/supabase-postgres-best-practices) | 440.4K | 2,766 |
| [web-design-guidelines](https://skills.sh/vercel-labs/agent-skills/web-design-guidelines) | 722.6K | 32,251 |
| [codebase-design](https://skills.sh/mattpocock/skills/codebase-design) | 777K | 286,514 |
| [caveman](https://skills.sh/juliusbrussee/caveman/caveman) | 567.6K | 111,085 |
| [expo-dev-client](https://skills.sh/expo/skills/expo-dev-client) | 66.1K | 2,760 |

Expo's search index still listed `upgrading-expo` and `expo-deployment`, but
`npx skills add https://github.com/expo/skills --list` exposed `expo-upgrade`
and `eas-app-stores` instead. Per-name adoption for those replacements was not
verified. Official source reputation supports inspection, not blindly treating
old names or install counts as current.

No extra generic brainstorm/planning/docs-writing skill, browser alternative,
or bulk framework bundle is selected here: Harness already supplies the first
category, and duplicates increase conflicting instructions and context cost.
