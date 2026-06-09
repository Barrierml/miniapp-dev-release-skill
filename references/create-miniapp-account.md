# Create A WeChat Mini Program Account

Use this when the user does not yet have a WeChat Mini Program account/AppID.

## Goal

Move the user from "no Mini Program account" to "Codex has a real AppID and can continue the automated release path".

Codex should not ask the user to learn the whole platform. Give a short, direct checklist, stop at account-sensitive steps, and resume once the user provides the AppID.

## Decision Tree

Ask or infer the user's state:

- Already has a Mini Program account: run `miniapp_release.sh handoff <project>` and ask only for AppID.
- Has an authenticated Official Account that can create/associate Mini Programs: tell the user they may use the public-platform quick-create/association entry if it is available in their account UI.
- Has no Mini Program account: guide them through public-platform registration.
- Unsure: send the `create-account` guide and ask them to report whether they reached an AppID page.

## Minimal Guide To Send The User

```text
你现在还没有小程序账号的话，先创建一个真实的小程序账号：

1. 打开 https://mp.weixin.qq.com/
2. 点注册入口，账号类型选「小程序」。
3. 用一个没有绑定过公众平台/开放平台账号的邮箱注册，并完成邮件激活。
4. 选择主体类型：个人、企业、政府、媒体或其他组织。个人主体适合轻量工具/个人项目；企业或组织主体更适合正式业务、品牌、支付或受监管类目。
5. 按页面要求完成管理员扫码、手机号、实名、打款/认证、资质上传等步骤。
6. 创建完成后，进入小程序后台的开发设置，复制 AppID。
7. 只把 AppID 发给我，格式类似 wx1234567890abcdef。不要发 AppSecret。

你完成到 AppID 这一步后，后面的配置、检测和上传我来接管。
```

## What Codex Can And Cannot Do

Codex can:

- Open the public-platform URL if browser/Computer Use is available.
- Read the visible state and tell the user exactly what page they are on.
- Explain which choice is appropriate for the target app.
- Update project config after AppID is provided.
- Run build/check/automator/upload.

Codex cannot safely do:

- Register an account with the user's email/phone/password on their behalf.
- Receive or store AppSecret, passwords, identity documents, cookies, or verification codes.
- Complete QR scans, identity checks, payment verification, qualification upload, or legal declarations for the user.
- Choose a regulated service category without user/business confirmation.

## Subject Type Guidance

Use plain guidance, not legal advice:

- Individual: simplest for personal tools, prototypes, demos, and non-payment lightweight apps.
- Enterprise or individual business: better for formal products, branding, customer service, payment-related flows, ecommerce, booking, or offline business.
- Government/media/other organization: only when the user actually belongs to that organization and has the required qualification.

If the app may involve medical, finance, education, payment, ecommerce, user-generated content, live streaming, or other regulated features, tell the user the platform may require extra categories, qualifications, filings, privacy materials, or review notes.

## Resume After Account Creation

Once the user sends a valid AppID:

```bash
scripts/miniapp_release.sh release /path/to/miniapp <appid> <version> "<desc>"
```

If upload fails for permission:

1. Ask the user to confirm the WeChat account logged in to Developer Tools is an administrator/developer of that Mini Program.
2. Ask the user to complete any QR/identity prompt.
3. Re-run `doctor`, `check`, and `upload`.

## Security Rules

- Ask for AppID only.
- Never ask for AppSecret. AppSecret belongs on a backend only when needed, never in miniapp front-end code or skill logs.
- Never ask for account password, cookies, private keys, identity documents, QR screenshots, or verification codes.
- If the user sends AppSecret or other sensitive data, tell them not to paste it again and avoid writing it to files.
