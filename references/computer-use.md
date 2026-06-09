# Computer Use Workflow

## Strong Recommendation

If Computer Use is disabled or unavailable, tell the user plainly:

```text
I can run CLI build/check/upload steps, but I strongly recommend enabling Computer Use before final mini program release QA. WeChat Developer Tools and the public platform have visual login, simulator, network, and audit-submission states that CLI output cannot fully verify.
```

Proceed with CLI-only checks only when the user accepts the reduced confidence or the task is purely deterministic.

If Computer Use is not exposed in the current Codex environment, use the best available fallback and say so:

- WeChat CLI for `doctor`, `open`, `auto`, `upload`.
- `miniprogram-automator` for real simulator taps, inputs, page data assertions, and screenshots.
- Manual user participation for QR codes, identity checks, and public-platform submit confirmation.

Label the result as reduced visual/account confidence when Computer Use was unavailable.

## When To Use Computer Use

Use Computer Use for:

- WeChat Developer Tools login or `islogin` failures.
- QR codes, identity verification, and public-platform login.
- Opening simulator pages and confirming visible UI.
- Clicking through public-platform audit submission.
- Inspecting network failures in Developer Tools.
- Visual QA for overflow, disabled buttons, modal blocking, or page blankness.

Do not use Computer Use for:

- Package scans, build commands, or upload CLI when those can run deterministically.
- Secret extraction or bypassing user-controlled account verification.

## Procedure

1. Open or bring the target app to front.
2. Read current app state before clicking.
3. State what page is visible and what action you will take.
4. Click/type only clearly identified controls.
5. Stop at QR code, captcha, identity verification, or account-risk prompts and ask the user to complete them.
6. After the user completes the account step, continue from the visible state.
7. Capture key observations: page, version, status, visible error, and final state.

## WeChat Developer Tools QA

Suggested path:

- Open built output with CLI.
- Use Computer Use to confirm the project loaded and simulator is not blank.
- Navigate to changed pages.
- For forms, type into real inputs and verify visible values.
- For network-sensitive flows, inspect request status and response errors.
- If simulator is stuck on login/authorization, ask user to complete auth or provide a test path.

## Public Platform Submission

Suggested path:

- Navigate to mini program version management.
- Confirm development version number and upload time.
- Do not publish an older approved audit version by accident.
- Click submit audit only for the intended development version.
- Confirm privacy choices and test notes match the feature set.
- After final submit, verify audit version changes to the intended version and state is reviewing/pending.
