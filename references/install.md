# Installation And Diagnosis

## Dependency Principle

Prefer native WeChat Mini Program development first. Do not install or introduce uni-app, HBuilderX, Taro, React/Vue builders, or other frameworks unless the repository already uses them or the user explicitly asks.

Native miniapp projects only need the WeChat project files and the WeChat Developer Tools toolchain. Framework projects need their own builder in addition to WeChat upload tooling.

## Required Components For Native Miniapps

- Node.js LTS.
- Project package manager only if `package.json` exists; prefer the repo lockfile (`pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`).
- WeChat Developer Tools desktop app and CLI.
- `ripgrep` for generated-package scans.
- Optional but recommended: `miniprogram-automator` for simulator automation.
- Computer Use plugin/tool enabled in Codex for visual QA and public-platform submission.

## Conditional Components

- HBuilderX with uni-app CLI: only for uni-app projects, or when no custom `BUILD_CMD` is available.
- `miniprogram-automator`: for automated simulator tests.
- Framework CLIs: only when the repo already uses that framework.

## Install Policy

Directly install safe local dependencies:

- Run the repo package-manager install.
- Enable Corepack when `pnpm`/Yarn is needed.
- Install `pnpm` through Corepack or npm if missing.
- Add `miniprogram-automator` only when the user wants automated simulator tests, or when the repo already uses it.
- For native projects that add local automation dependencies beside `app.json`, add `node_modules`, automation `scripts`, `package.json`, lockfiles, and `project.private.config.json` to `project.config.json` `packOptions.ignore` unless the miniapp intentionally packages npm modules.
- Install Node with Homebrew if Homebrew exists and Node is missing.

Guide the user for app/account-bound components:

- WeChat Developer Tools may require a browser/app download, app launch, and WeChat login.
- Upload requires a real Mini Program AppID and account permission. `touristappid` can open and self-test locally, but should be treated as upload-blocking.
- HBuilderX may require a GUI installation and plugin setup, but only mention it as blocking for uni-app projects.
- WeChat public platform requires account login, QR scan, identity verification, and permission checks.
- Computer Use must be enabled by the user in Codex; if it is disabled, strongly recommend enabling it before final QA/upload/submission.

## Missing Component Report

When `doctor` reports missing components, tell the user:

- Exact missing component.
- Why it matters.
- Whether Codex can install it directly.
- The next command or manual action.

Keep the report actionable, for example:

```text
Missing:
- WeChat Developer Tools CLI: required for open/upload. Install WeChat Developer Tools, then verify /Applications/wechatwebdevtools.app/Contents/MacOS/cli.
- HBuilderX uni CLI: required only because this repo is uni-app and no BUILD_CMD was provided. Install HBuilderX and the uni-app plugin, or provide BUILD_CMD.

Installed/handled:
- pnpm dependencies installed.
- miniprogram-automator added as dev dependency.
```
