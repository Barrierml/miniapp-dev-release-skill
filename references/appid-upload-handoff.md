# AppID And Upload Handoff

Use this when the miniapp is ready locally but `project.config.json` still has `touristappid`, a missing AppID, or a wrong AppID.

If the user does not have a Mini Program account yet, use `references/create-miniapp-account.md` first.

## Principle

Codex should do every deterministic step and ask the user only for account-owned actions:

- The user logs in to the correct WeChat public-platform Mini Program account.
- The user provides the Mini Program AppID only.
- The user scans QR codes, identity checks, or permission prompts.

Codex handles:

- Detecting missing or placeholder AppID.
- Explaining where to find the AppID.
- Validating the AppID shape.
- Writing it into `project.config.json`.
- Removing `appid` from `project.private.config.json` if it would override the shared config.
- Re-running build/check/self-test.
- Uploading with WeChat Developer Tools CLI.
- Reporting upload info and next audit step.

Never ask the user for AppSecret, cookies, private keys, access tokens, QR screenshots, or verification codes.

## Minimal User Prompt

When AppID is missing, say:

```text
现在只差真实小程序 AppID。请打开 https://mp.weixin.qq.com/，登录要上线的那个小程序账号，在「开发 / 开发管理 / 开发设置」里的开发者 ID 区域复制 AppID。

只发 AppID 给我就行，格式类似 wx1234567890abcdef。不要发 AppSecret。
确认一下：微信开发者工具里登录的微信号也需要是这个小程序的管理员或开发者。
```

Then run:

```bash
scripts/miniapp_release.sh release /path/to/miniapp <appid> <version> "<desc>"
```

## Helper Commands

Print the handoff:

```bash
scripts/miniapp_release.sh handoff /path/to/miniapp
```

Show or bind AppID:

```bash
scripts/miniapp_release.sh appid /path/to/miniapp
scripts/miniapp_release.sh appid /path/to/miniapp wx1234567890abcdef
```

Bind, build, check, and upload:

```bash
scripts/miniapp_release.sh release /path/to/miniapp wx1234567890abcdef 1.0.0 "release notes"
```

If a real AppID is already bound:

```bash
scripts/miniapp_release.sh release /path/to/miniapp keep 1.0.1 "release notes"
```

## Pre-Upload Checklist

Before `upload`, confirm:

- `project.config.json` has a real `wx...` AppID.
- `project.private.config.json` does not override `appid`.
- WeChat Developer Tools `islogin` is true.
- The logged-in WeChat account has administrator/developer permission for this Mini Program.
- Package checks pass.
- Real simulator smoke tests pass, or skipped checks are explicitly reported.
- Version and description are correct.

## Failure Handling

- Invalid AppID: ask only for the AppID again; do not ask for AppSecret.
- `touristappid`: local development is okay, upload is blocked.
- Upload permission error: ask the user to log in to WeChat Developer Tools with an authorized administrator/developer account, or add this WeChat account as a project member in the public platform.
- QR/identity prompt: stop and ask the user to complete it; continue after they confirm.
- AppID mismatch between public platform and DevTools project: run `appid <project> <appid>` again, reopen Developer Tools, and retry `doctor/check/upload`.
- `project.private.config.json` contains `appid`: block upload and run `appid <project> <appid>` to remove the private override.

## Notes From WeChat Tooling

- WeChat Developer Tools CLI `upload` requires version and description.
- When `--project` is provided, the CLI ignores `--appid`; therefore the AppID must be in the project configuration, not only in the upload command.
- `project.private.config.json` can override shared project settings, so remove private `appid` overrides before upload.
