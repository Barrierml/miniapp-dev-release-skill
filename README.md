# Miniapp Dev Release Skill

Codex skill for developing, configuring, self-testing, uploading, and submitting WeChat Mini Programs.

It is native-miniapp first: use WeChat `app.json` / WXML / WXSS / JS directly when possible, and only reach for uni-app, HBuilderX, or other frameworks when the project already depends on them.

## What It Helps With

- Build a native WeChat Mini Program from an empty directory.
- Implement or modify pages, components, routes, tabBar, project config, and package ignore rules.
- Diagnose local miniapp tooling: Node.js, package manager, WeChat Developer Tools CLI, `ripgrep`, optional HBuilderX and simulator automation.
- Build native or uni-app miniapp output.
- Run deterministic package checks before upload.
- Guide AppID handoff without collecting AppSecret, passwords, cookies, QR screenshots, or verification codes.
- Bind a real Mini Program AppID safely and remove private AppID overrides.
- Upload development versions through WeChat Developer Tools CLI.
- Strongly recommend Computer Use for visual QA, simulator checks, and public-platform audit submission.

## Install

Clone this repository into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Barrierml/miniapp-dev-release-skill.git ~/.codex/skills/miniapp-dev-release
```

Then ask Codex to use `$miniapp-dev-release` when working on a WeChat Mini Program.

## Quick Commands

The helper script is optional. Use it when the target project does not already provide a better release script.

```bash
./scripts/miniapp_release.sh scaffold-native /path/to/new-miniapp "Demo Miniapp"
./scripts/miniapp_release.sh doctor /path/to/miniapp
./scripts/miniapp_release.sh install /path/to/miniapp
./scripts/miniapp_release.sh build /path/to/miniapp
./scripts/miniapp_release.sh check /path/to/miniapp
./scripts/miniapp_release.sh handoff /path/to/miniapp
./scripts/miniapp_release.sh release /path/to/miniapp wx1234567890abcdef 1.0.0 "release notes"
```

## Project Modes

- `native`: contains `project.config.json` and `app.json`; build/check/upload operate on that directory directly.
- `uni-app`: contains `manifest.json` or `pages.json`; build output is usually `unpackage/dist/build/mp-weixin`.
- `custom`: set `BUILD_CMD` and `OUTPUT_DIR` when a repository uses another builder.

## Safety Rules

- Do not ask users for AppSecret, account passwords, cookies, identity documents, private keys, or verification codes.
- Do not introduce a framework unless the target project already uses it or the user asks for it.
- Do not upload before a production build and package checks.
- Do not commit `project.private.config.json`, upload info JSON, token files, local cookies, or screenshots containing QR/session material.
- Stop at account-sensitive confirmations and let the user complete QR, captcha, payment verification, or identity checks directly.

## Repository Layout

```text
SKILL.md
agents/openai.yaml
references/
scripts/miniapp_release.sh
```

## License

MIT.
