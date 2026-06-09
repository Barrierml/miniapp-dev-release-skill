---
name: miniapp-dev-release
description: Develop, configure, debug, visually self-test, upload, and submit WeChat Mini Programs with a native-miniapp-first workflow and optional uni-app compatibility. Use when users ask to build a miniapp from zero, scaffold native app.json/pages/WXML/WXSS/JS, implement or modify pages/components, configure AppID/project settings/tabBar/routes/packOptions, reduce framework dependencies, diagnose WeChat DevTools/Node/package tooling, handle existing uni-app/HBuilderX projects only when needed, run automated package and simulator checks, use Computer Use for visual QA or public-platform UI testing, upload a development version, or prepare/guide audit submission.
---

# Miniapp Development And Release

## Purpose

Use this skill to take a WeChat Mini Program from idea or local code to a verified upload. Prefer native WeChat mini program structure and minimum dependencies; keep uni-app/HBuilderX only when the repository actually needs them.

## Quick Start

Use the bundled helper when a repo does not already have a better project-specific script. Resolve the path relative to this skill directory:

```bash
scripts/miniapp_release.sh scaffold-native /path/to/new-miniapp "Demo Miniapp"
scripts/miniapp_release.sh doctor /path/to/miniapp
scripts/miniapp_release.sh install /path/to/miniapp
scripts/miniapp_release.sh build /path/to/miniapp
scripts/miniapp_release.sh check /path/to/miniapp
scripts/miniapp_release.sh create-account
scripts/miniapp_release.sh handoff /path/to/miniapp
scripts/miniapp_release.sh appid /path/to/miniapp wx1234567890abcdef
scripts/miniapp_release.sh upload /path/to/miniapp 1.0.0 "release notes"
scripts/miniapp_release.sh release /path/to/miniapp wx1234567890abcdef 1.0.0 "release notes"
```

Project modes:

- `native`: source directory contains `project.config.json` and `app.json`; build/check/open/upload operate on that directory directly.
- `uni-app`: source directory contains `manifest.json` or `pages.json`; build creates/uses `unpackage/dist/build/mp-weixin`.
- `custom`: set `BUILD_CMD` and `OUTPUT_DIR` when the repo uses another builder.

Important environment overrides:

- `BUILD_CMD`: project-specific build command, for example `pnpm run build:mp-weixin`.
- `OUTPUT_DIR`: built `mp-weixin` directory for framework/custom projects.
- `WECHAT_CLI`: WeChat Developer Tools CLI path.
- `UNI_CLI`: HBuilderX uni-app CLI path.
- `CHECK_PATTERNS`: release-blocking text patterns for package scan.
- `INFO_DIR`: upload info JSON output directory.

## Workflow

1. Start from the right shape.
   - If the user wants a new miniapp, read `references/native-from-zero.md` and run `miniapp_release.sh scaffold-native <dir> "<name>"` unless a project already exists.
   - If a project already exists, inspect it before changing anything.
   - Run `git status --short`.
   - Read `AGENTS.md`, `CLAUDE.md`, release docs, and existing scripts such as `script/miniapp_debug.sh`.
   - If a project-specific release script exists, prefer it over the generic helper.

2. Develop and configure.
   - Keep native miniapps native by default: app shell, routes, pages, components, styles, storage/request helpers.
   - For feature work, implement the smallest usable workflow first, then add release/self-test coverage for the risky path.
   - Maintain `app.json`, page JSON, tabBar, `project.config.json`, and `packOptions.ignore` deliberately.
   - Avoid landing-page filler when the user asked for an app/tool; make the first screen usable.

3. Determine account/AppID state.
   - If the user has no Mini Program account, read `references/create-miniapp-account.md` and run `miniapp_release.sh create-account` to give the minimum account-creation guide.
   - If the user has an account but no AppID in the project, run `miniapp_release.sh handoff <repo>` and ask only for the AppID.
   - Never ask for AppSecret, account password, cookies, verification codes, private keys, or identity documents.
   - Resume automation after the user provides a valid `wx...` AppID.

4. Diagnose installation.
   - Run `miniapp_release.sh doctor <repo>`.
   - Clearly tell the user which components are present and which are missing.
   - Treat HBuilderX as optional for native projects.
   - For install policy and manual steps, read `references/install.md`.

5. Install what can be installed.
   - Run package-manager install for repo dependencies when appropriate.
   - Enable Corepack or install `pnpm` only if the project needs it.
   - Do not install frameworks by default. Keep native projects native unless the user chooses a framework.
   - Do not pretend WeChat Developer Tools is installed if its CLI path is missing; guide the user through app installation.
   - Require HBuilderX only for uni-app projects without another `BUILD_CMD`.

6. Build production output.
   - For native projects, skip build unless `BUILD_CMD` or a package `build` script exists.
   - Use production env and production backend settings for release uploads.
   - Do not upload dev/test output unless the user explicitly asks for a test upload.
   - For uni-app, output is usually `unpackage/dist/build/mp-weixin`.

7. Run deterministic self-checks.
   - For native projects, scan the native project directory.
   - For framework projects, scan generated output.
   - Exclude local-only directories such as `node_modules`, `.git`, and coverage output from package-size checks; native projects often keep optional automation dependencies beside `app.json`, but those should be ignored through `packOptions.ignore`.
   - Run package size/file-count scan.
   - Scan for known forbidden or stale copy.
   - Scan generated routes/pages when review risk depends on removed pages.
   - Read `references/self-test.md` for the checklist.

8. Strongly recommend Computer Use.
   - If Computer Use is unavailable or disabled, tell the user it is strongly recommended for miniapp release QA because CLI cannot see visual overlap, auth prompts, simulator state, or public-platform submission UI.
   - If available, use it for WeChat Developer Tools login, simulator smoke tests, screenshots, network panel checks, and public-platform audit submission. Read `references/computer-use.md`.

9. Automate simulator checks when possible.
   - Use WeChat CLI `auto` with `--auto-port`.
   - Do not hard-code an IDE server port after `doctor` or `open`; WeChat Developer Tools may already be listening on another port. Omit `--port` unless a known port is required, or reuse the port printed by CLI.
   - If the automation port is already listening, connect to `ws://127.0.0.1:<auto-port>` instead of starting `auto` again.
   - Use `miniprogram-automator` to click/tap/type real controls.
   - Give every automator smoke test a timeout and make it idempotent when local storage or prior page state can persist between runs.
   - For form changes, test real input values, not only code assertions.

10. Upload.
   - Bump version before upload.
   - Run production build and checks immediately before upload.
   - Require a real AppID in `project.config.json`; `touristappid` is fine for local development and simulator checks, but cannot be uploaded.
   - If a real AppID is missing, run `miniapp_release.sh handoff <repo>` and ask the user only for the Mini Program AppID, not AppSecret.
   - After receiving the AppID, use `miniapp_release.sh release <repo> <appid> <version> "<desc>"` to bind AppID, build, check, and upload in one pass.
   - Clear `project.private.config.json` `appid` overrides when binding AppID, because private config can override the shared project AppID.
   - Use WeChat CLI `upload --project <output> --version <version> --desc <desc> --info-output <json>`.
   - Report total package, main package, subpackages, version, and upload info path.

11. Submit audit.
   - WeChat CLI uploads a development version; public-platform audit submission may still need UI.
   - Use Computer Use for final submit clicks after user handles QR/login/identity checks.
   - After submission, verify the audit version and state.

12. Record release notes.
   - Append a concise changelog entry if the project has a docs/changelog convention.
   - Include commands run, package sizes, upload version, audit state, and any skipped checks.

## Guardrails

- Do not upload before production build and package checks.
- Do not introduce uni-app, Taro, Vue, React, or another framework unless the repo already uses it or the user asks.
- Do not deploy backend unless backend files changed or the user asks.
- Do not commit secrets, app private keys, tokens, cookies, or upload JSON containing sensitive credentials.
- Do not click through QR codes, identity verification, or account-sensitive confirmations without the user handling the account step.
- If package checks fail, stop and fix or explicitly report the blocking matches.
- Keep screenshots and visual observations short: current page, visible issue, action taken.

## Resources

- `scripts/miniapp_release.sh`: generic scaffold/install/build/check/open/upload helper.
- `references/create-miniapp-account.md`: guide users who do not yet have a Mini Program account.
- `references/appid-upload-handoff.md`: minimum-human-intervention AppID handoff and upload path.
- `references/install.md`: dependency diagnosis and installation policy.
- `references/native-from-zero.md`: native miniapp scaffolding path and lab pitfalls.
- `references/self-test.md`: deterministic and simulator self-test checklist.
- `references/computer-use.md`: Computer Use and WeChat UI workflow.
