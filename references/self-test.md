# Miniapp Self-Test Checklist

## Deterministic Checks

Run before upload:

- Git status and version bump check.
- Production build if the project has a build step. Native miniapps can often skip build and upload the source project directly.
- Package size and file count.
- Generated text scan for stale/forbidden copy.
- Route/page existence scan when a feature was removed for audit risk.
- API base URL check: release output must point to production unless doing an explicit test upload.
- `app.json` / `project.config.json` sanity check.

Common generated text risks:

- Appointment review: `预约签到`, `签到码`, `挂号机`, `加号机`.
- Community/forum review: `帖子`, `评论`, `回复`, `发帖`, `用户回复`.
- Product-specific sensitive words should be added through `CHECK_PATTERNS`.

## Simulator Checks

Use real simulator interaction for changes to:

- Form input, numeric defaults, validation, radio/checkbox logic.
- Login/authorization flows.
- Navigation, tabbar, subpackage pages.
- Upload/download/file preview.
- Appointment, schedule, payment-like, or admin flows.

For uni-app/WeChat:

1. Open the native miniapp project directory, or the built `mp-weixin` directory for framework projects, in WeChat Developer Tools.
2. Start CLI automation: `cli auto --project <output> --trust-project --auto-port <auto-port>`; add `--port <ide-port>` only when a specific IDE server port is known.
3. Connect with `miniprogram-automator`.
4. `tap()` real controls and `input()` real inputs.
5. Assert page data and visible text after each important interaction.

Port and state rules:

- If `doctor` or `open` already started WeChat Developer Tools, omit `--port` or reuse the IDE server port printed by CLI. Starting `auto` with a different IDE port can fail.
- If `--auto-port` is already listening, do not start another `auto`; connect to `ws://127.0.0.1:<auto-port>`.
- Add a hard timeout to every smoke test so a half-open DevTools automation connection does not hang forever.
- Make scripts idempotent. Local storage, tab state, and switches can survive between runs, so read current page data before toggling.

Example expectation for numeric field bugs:

- Type `0` into the real input.
- Confirm input value is `0`.
- Confirm component state is `0`.
- Confirm section/form data is `0`.
- Confirm no validation error appears.

## Visual QA

Use Computer Use or screenshots for:

- Text overflow, clipped buttons, overlapping modals.
- Login/permission prompts.
- Developer Tools simulator state.
- Network panel and failed requests.
- Public-platform version/audit pages.

Report skipped checks explicitly. A clean release report should include commands run, package sizes, simulator flows tested, upload version, and remaining risks.
