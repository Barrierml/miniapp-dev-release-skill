# Native Miniapp From Zero

Use this path when the user wants to build a WeChat Mini Program directly with native miniapp files, without uni-app or another framework.

## Minimal Project Shape

Create these files first:

- `project.config.json`: WeChat Developer Tools project settings.
- `app.json`: page list, window, tabBar, global components.
- `app.js`: application lifecycle and global data.
- `app.wxss`: global visual system.
- `pages/<name>/<name>.json|wxml|wxss|js`: every page.
- `components/<name>/<name>.json|wxml|wxss|js`: reusable UI only when duplication is real.
- `utils/*.js`: shared storage, formatting, request helpers.

Start with `appid: "touristappid"` only for local development. Before upload, replace it with the real Mini Program AppID and verify account permissions in WeChat Developer Tools.

For the final handoff, do not ask for broad account details. Ask only for the AppID value from the target Mini Program account, then run `miniapp_release.sh release <project> <appid> <version> "<desc>"`.

If the user does not have a Mini Program account, send the account-creation guide first. Keep building locally with `touristappid` while they complete account registration.

## Recommended Build-Up Order

1. Create the app shell with `scripts/miniapp_release.sh scaffold-native <project> "<name>"`, or manually create `project.config.json`, `app.json`, `app.js`, `app.wxss`.
2. Add the first usable page immediately. Avoid a marketing landing page when the request is an app/tool.
3. Add tabBar or navigation only when there are multiple real workflows.
4. Add storage or request helpers before pages start duplicating local-state logic.
5. Add one release/self-test page that exercises the risky user input or workflow.
6. Run `miniapp_release.sh doctor`, `build`, `check`, and `open`.
7. Add `miniprogram-automator` only when simulator automation is needed.
8. Add `packOptions.ignore` for local automation files before upload.

## Native Project `packOptions.ignore`

If optional automation dependencies are installed beside `app.json`, ignore local-only files:

```json
{
  "packOptions": {
    "ignore": [
      { "type": "folder", "value": "node_modules" },
      { "type": "folder", "value": "scripts" },
      { "type": "file", "value": "package.json" },
      { "type": "file", "value": "package-lock.json" },
      { "type": "file", "value": ".gitignore" },
      { "type": "file", "value": "project.private.config.json" }
    ]
  }
}
```

Do not ignore `node_modules` if the miniapp intentionally packages built npm modules from that directory. Prefer the WeChat npm build output pattern in that case.

## Automator Smoke Test Template

1. Start automation:

```bash
scripts/miniapp_release.sh auto /path/to/native-miniapp
```

2. Connect from Node:

```js
const automator = require('miniprogram-automator');
const miniProgram = await automator.connect({ wsEndpoint: 'ws://127.0.0.1:9420' });
const page = await miniProgram.switchTab('/pages/self-test/self-test');
```

3. Use real controls:

- `await input.input('0')`
- `await switchEl.tap()`
- `await button.tap()`
- `await page.data()` assertions

Always add a timeout and read current page data before toggling persisted switches.

## Pitfalls Found During The Lab

- WeChat CLI `doctor` or `open` can start the IDE server on a dynamic port such as `12695`; later `auto --port 9421` fails. Omit `--port` unless required, or reuse the printed IDE port.
- If `--auto-port` is already listening, connect to it instead of starting another automation server.
- Installing `miniprogram-automator` in a native root inflates local directory size; package checks and `packOptions.ignore` must exclude local-only automation files.
- WeChat Developer Tools may create `project.private.config.json`; treat it as local-only and ignore it for git/package scans unless the team explicitly tracks private overrides.
- `touristappid` works for local development, open, and simulator tests, but upload must be blocked until a real AppID is configured.
- Smoke tests must be idempotent because local storage persists between runs.
