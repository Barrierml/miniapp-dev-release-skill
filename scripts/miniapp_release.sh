#!/usr/bin/env bash
set -euo pipefail

DEFAULT_WECHAT_CLI="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
DEFAULT_UNI_CLI="/Applications/HBuilderX.app/Contents/HBuilderX/plugins/uniapp-cli/bin/uniapp-cli.js"

script_path() {
  local src="${BASH_SOURCE[0]}"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$src"
  else
    cd "$(dirname "$src")" >/dev/null
    printf "%s/%s\n" "$(pwd)" "$(basename "$src")"
  fi
}

usage() {
  cat <<'USAGE'
miniapp_release.sh <command> <project_dir> [args]

Commands:
  doctor <project_dir>                 Check local toolchain and project shape
  install <project_dir> [--with-automator]
                                       Install project deps; optionally add miniprogram-automator
  build <project_dir>                  Build release output
  check <project_dir>                  Inspect package size and blocking text patterns
  open <project_dir>                   Open built output in WeChat Developer Tools
  auto <project_dir> [ide_port] [auto_port]
                                       Start WeChat DevTools automation server
  create-account                       Print minimal guide for users without a Mini Program account
  handoff <project_dir>                Print the minimal user handoff for real AppID/account steps
  appid <project_dir> [appid]          Show or bind a real Mini Program AppID
  upload <project_dir> <version> <desc>
                                       Upload built output with WeChat CLI
  release <project_dir> <appid|keep> <version> <desc>
                                       Bind AppID if needed, then build, check, and upload
  info <project_dir> <version>         Print upload info JSON

Environment overrides:
  BUILD_CMD       Project build command. If set, it is used for build.
  OUTPUT_DIR      Built mp-weixin directory for framework projects.
  WECHAT_CLI      WeChat DevTools CLI. Default: /Applications/wechatwebdevtools.app/Contents/MacOS/cli
  UNI_CLI         HBuilderX uni-app CLI. Default: /Applications/HBuilderX.app/.../uniapp-cli.js
  HBX_CONTEXT     HBuilderX uni-app context. Default: dirname(UNI_CLI)
  CHECK_PATTERNS  ripgrep pattern for blocking generated text
  INFO_DIR        Upload info JSON dir. Default: /tmp
USAGE
}

project_dir() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    echo "project_dir is required" >&2
    exit 2
  fi
  cd "$dir" >/dev/null
  pwd
}

wechat_cli() {
  echo "${WECHAT_CLI:-$DEFAULT_WECHAT_CLI}"
}

uni_cli() {
  echo "${UNI_CLI:-$DEFAULT_UNI_CLI}"
}

output_dir() {
  local dir="$1"
  echo "${OUTPUT_DIR:-$dir/unpackage/dist/build/mp-weixin}"
}

project_type() {
  local dir="$1"
  if [[ -f "$dir/project.config.json" && -f "$dir/app.json" ]]; then
    echo "native"
  elif [[ -f "$dir/manifest.json" || -f "$dir/pages.json" ]]; then
    echo "uni-app"
  else
    echo "unknown"
  fi
}

miniapp_project_dir() {
  local dir="$1"
  local type
  type="$(project_type "$dir")"
  if [[ "$type" == "native" ]]; then
    echo "$dir"
    return
  fi

  local out
  out="$(output_dir "$dir")"
  if [[ -d "$out" ]]; then
    echo "$out"
    return
  fi

  echo "$out"
}

info_file() {
  local version="$1"
  echo "${INFO_DIR:-/tmp}/miniapp-upload-$version.json"
}

pm() {
  local dir="$1"
  if [[ -f "$dir/pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$dir/yarn.lock" ]]; then
    echo "yarn"
  elif [[ -f "$dir/package-lock.json" ]]; then
    echo "npm"
  else
    echo "npm"
  fi
}

pm_add_dev() {
  local manager="$1"
  local package="$2"
  case "$manager" in
    pnpm) pnpm add -D "$package" ;;
    yarn) yarn add -D "$package" ;;
    npm) npm install -D "$package" ;;
    *) "$manager" install -D "$package" ;;
  esac
}

find_package_files() {
  local out="$1"
  find "$out" \
    \( \( -name node_modules -o -name .git -o -name .svn -o -name .hg -o -name .idea -o -name .vscode -o -name coverage -o -name scripts \) -type d \) -prune \
    -o \( \( -name package.json -o -name package-lock.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name .gitignore -o -name project.private.config.json -o -name README.md \) -type f \) -prune \
    -o -type f -print
}

package_size_bytes() {
  local out="$1"
  local file size total=0
  while IFS= read -r file; do
    if size="$(stat -f%z "$file" 2>/dev/null)"; then
      :
    elif size="$(stat -c%s "$file" 2>/dev/null)"; then
      :
    else
      size=0
    fi
    total=$((total + size))
  done < <(find_package_files "$out")
  echo "$total"
}

human_size() {
  awk -v bytes="$1" 'BEGIN {
    split("B KB MB GB", unit, " ");
    value = bytes + 0;
    idx = 1;
    while (value >= 1024 && idx < 4) {
      value = value / 1024;
      idx++;
    }
    printf "%.1f%s\n", value, unit[idx];
  }'
}

json_value() {
  local file="$1"
  local key="$2"
  node -e "const fs=require('fs'); const p='$file'; if(!fs.existsSync(p)){process.exit(0)} const s=fs.readFileSync(p,'utf8'); const m=s.match(new RegExp('\"$key\"\\\\s*:\\\\s*\"?([^\",}]+)\"?')); console.log(m ? m[1] : '')"
}

miniapp_appid() {
  local out="$1"
  if [[ -f "$out/project.config.json" ]]; then
    json_value "$out/project.config.json" appid
  fi
}

miniapp_private_appid() {
  local out="$1"
  if [[ -f "$out/project.private.config.json" ]]; then
    json_value "$out/project.private.config.json" appid
  fi
}

is_real_appid() {
  local appid="${1:-}"
  [[ "$appid" =~ ^wx[0-9A-Fa-f]{16}$ ]]
}

set_project_appid() {
  local project="$1"
  local appid="$2"
  if [[ ! -f "$project/project.config.json" ]]; then
    echo "project.config.json not found in $project" >&2
    exit 1
  fi
  node - "$project/project.config.json" "$project/project.private.config.json" "$appid" <<'NODE'
const fs = require('fs');
const [configPath, privatePath, appid] = process.argv.slice(2);

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJson(file, data) {
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

const config = readJson(configPath);
config.appid = appid;
writeJson(configPath, config);

if (fs.existsSync(privatePath)) {
  const privateConfig = readJson(privatePath);
  if (Object.prototype.hasOwnProperty.call(privateConfig, 'appid')) {
    delete privateConfig.appid;
    writeJson(privatePath, privateConfig);
    console.log('removed appid from project.private.config.json to avoid overriding project.config.json');
  }
}
NODE
}

status_line() {
  local name="$1"
  local ok="$2"
  local detail="$3"
  if [[ "$ok" == "ok" ]]; then
    printf "OK      %-24s %s\n" "$name" "$detail"
  else
    printf "MISSING %-24s %s\n" "$name" "$detail"
  fi
}

cmd_doctor() {
  local dir
  dir="$(project_dir "$1")"
  local wc uc out manager
  wc="$(wechat_cli)"
  uc="$(uni_cli)"
  out="$(miniapp_project_dir "$dir")"
  manager="$(pm "$dir")"
  local type
  type="$(project_type "$dir")"

  echo "project=$dir"
  echo "project_type=$type"
  echo "package_manager=$manager"
  echo "miniapp_project=$out"
  [[ -d "$dir/.git" ]] && git -C "$dir" status --short || true

  command -v node >/dev/null 2>&1 && status_line "node" ok "$(node -v)" || status_line "node" missing "Install Node.js LTS"
  command -v "$manager" >/dev/null 2>&1 && status_line "$manager" ok "$("$manager" --version 2>/dev/null | head -1)" || status_line "$manager" missing "Install or enable $manager"
  command -v rg >/dev/null 2>&1 && status_line "ripgrep" ok "$(rg --version | head -1)" || status_line "ripgrep" missing "Install ripgrep for package scans"
  [[ -x "$wc" ]] && status_line "WeChat CLI" ok "$wc" || status_line "WeChat CLI" missing "$wc"
  if [[ "$type" == "uni-app" ]]; then
    [[ -f "$uc" ]] && status_line "HBuilderX uni CLI" ok "$uc" || status_line "HBuilderX uni CLI" missing "$uc"
  else
    [[ -f "$uc" ]] && status_line "HBuilderX uni CLI" ok "optional; native project does not require it" || status_line "HBuilderX uni CLI" ok "not required for native project"
  fi
  if [[ -f "$dir/package.json" ]]; then
    status_line "package.json" ok "found"
  elif [[ "$type" == "native" ]]; then
    status_line "package.json" ok "optional; native project has no npm build step"
  else
    status_line "package.json" missing "not found"
  fi
  if [[ -f "$dir/manifest.json" ]]; then
    status_line "manifest.json" ok "versionName=$(json_value "$dir/manifest.json" versionName) versionCode=$(json_value "$dir/manifest.json" versionCode)"
  elif [[ "$type" == "native" ]]; then
    status_line "manifest.json" ok "not required for native project"
  else
    status_line "manifest.json" missing "not found"
  fi
  if [[ -f "$dir/project.config.json" ]]; then
    status_line "project.config.json" ok "appid=$(json_value "$dir/project.config.json" appid)"
  elif [[ -f "$(output_dir "$dir")/project.config.json" ]]; then
    status_line "project.config.json" ok "found in output appid=$(json_value "$(output_dir "$dir")/project.config.json" appid)"
  else
    status_line "project.config.json" missing "not found in source or output"
  fi
  local appid private_appid
  appid="$(miniapp_appid "$out")"
  private_appid="$(miniapp_private_appid "$out")"
  if is_real_appid "$appid"; then
    status_line "upload AppID" ok "$appid"
  else
    status_line "upload AppID" missing "current appid=${appid:-missing}; bind a real wx... AppID before upload"
  fi
  if [[ -n "$private_appid" ]]; then
    status_line "private AppID override" missing "project.private.config.json appid=$private_appid overrides shared config; run appid command to clean it"
  else
    status_line "private AppID override" ok "none"
  fi
  if [[ "$type" == "native" ]]; then
    [[ -d "$out" ]] && status_line "miniapp project" ok "$out" || status_line "miniapp project" missing "$out"
  else
    [[ -d "$out" ]] && status_line "built output" ok "$out" || status_line "built output" missing "run build first"
  fi

  if [[ -x "$wc" ]]; then
    "$wc" islogin || true
  fi
}

cmd_install() {
  local dir
  dir="$(project_dir "$1")"
  shift || true
  local with_automator="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-automator) with_automator="true" ;;
      *) echo "unknown install option: $1" >&2; exit 2 ;;
    esac
    shift
  done

  if ! command -v node >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      brew install node
    else
      echo "Node.js is missing and Homebrew is unavailable; install Node.js LTS manually." >&2
      exit 1
    fi
  fi

  local manager
  manager="$(pm "$dir")"
  if [[ "$manager" == "pnpm" ]] && ! command -v pnpm >/dev/null 2>&1; then
    corepack enable || npm install -g pnpm
  fi

  cd "$dir"
  if [[ -f "$dir/package.json" ]]; then
    "$manager" install
  else
    echo "No package.json; skipping package-manager install."
  fi

  if [[ "$with_automator" == "true" ]]; then
    if [[ ! -f "$dir/package.json" ]]; then
      npm init -y
    fi
    node -e "const p=require('./package.json'); process.exit((p.dependencies&&p.dependencies['miniprogram-automator'])||(p.devDependencies&&p.devDependencies['miniprogram-automator'])?0:1)" \
      || pm_add_dev "$manager" miniprogram-automator
  fi
}

cmd_build() {
  local dir
  dir="$(project_dir "$1")"
  cd "$dir"

  if [[ -n "${BUILD_CMD:-}" ]]; then
    eval "$BUILD_CMD"
    return
  fi

  local type
  type="$(project_type "$dir")"

  if [[ "$type" == "native" ]]; then
    local manager
    manager="$(pm "$dir")"
    if [[ -f "$dir/package.json" ]] && node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts.build?0:1)" 2>/dev/null; then
      "$manager" run build
    else
      echo "Native miniapp project detected; no build step required without BUILD_CMD or package build script."
    fi
    return
  fi

  local uc hbx out
  uc="$(uni_cli)"
  hbx="${HBX_CONTEXT:-$(dirname "$uc")}"
  out="$(output_dir "$dir")"

  if [[ -f "$uc" ]]; then
    NODE_ENV=production \
    UNI_PLATFORM=mp-weixin \
    UNI_INPUT_DIR="$dir" \
    UNI_OUTPUT_DIR="$out" \
    UNI_SCRIPT="${UNI_SCRIPT:-weixin-prod}" \
    VUE_CLI_CONTEXT="$hbx" \
    node "$uc"
    return
  fi

  local manager
  manager="$(pm "$dir")"
  if node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts['build:mp-weixin']?0:1)" 2>/dev/null; then
    "$manager" run build:mp-weixin
  elif node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts.build?0:1)" 2>/dev/null; then
    "$manager" run build
  else
    echo "No BUILD_CMD, HBuilderX uni CLI, or package build script found." >&2
    exit 1
  fi
}

cmd_check() {
  local dir
  dir="$(project_dir "$1")"
  local out patterns
  out="$(miniapp_project_dir "$dir")"
  patterns="${CHECK_PATTERNS:-预约签到|签到码|挂号机|加号机|用户回复|评论|发帖|帖子}"

  if [[ ! -d "$out" ]]; then
    echo "miniapp project/output not found: $out" >&2
    exit 1
  fi

  local bytes count
  bytes="$(package_size_bytes "$out")"
  count="$(find_package_files "$out" | wc -l | awk '{print $1}')"

  echo "miniapp_project=$out"
  echo "package_size=$(human_size "$bytes")"
  echo "package_bytes=$bytes"
  echo "file_count=$count"
  echo "scan_excludes=node_modules,.git,.svn,.hg,.idea,.vscode,coverage,scripts,package.json,lockfiles,project.private.config.json,README.md"
  find "$out" -maxdepth 2 -type f \( -name 'app.json' -o -name 'project.config.json' -o -name 'app.js' \) -print

  if command -v rg >/dev/null 2>&1; then
    echo "blocking_pattern_matches:"
    if rg -n "$patterns" "$out" -g '!node_modules/**' -g '!.git/**' -g '!coverage/**' -g '!scripts/**' -g '!package.json' -g '!package-lock.json' -g '!pnpm-lock.yaml' -g '!yarn.lock' -g '!project.private.config.json' -g '!README.md'; then
      echo "Blocking patterns found. Fix generated output or override CHECK_PATTERNS if this is intentional." >&2
      exit 1
    fi
  else
    echo "ripgrep missing; skipped blocking text scan" >&2
  fi
}

cmd_open() {
  local dir out wc
  dir="$(project_dir "$1")"
  out="$(miniapp_project_dir "$dir")"
  wc="$(wechat_cli)"
  "$wc" open --project "$out"
}

cmd_auto() {
  local dir out wc ide_port auto_port
  dir="$(project_dir "$1")"
  ide_port="${2:-}"
  auto_port="${3:-9420}"
  out="$(miniapp_project_dir "$dir")"
  wc="$(wechat_cli)"
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$auto_port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "auto_port=$auto_port already listening; connect miniprogram-automator to ws://127.0.0.1:$auto_port"
    return
  fi
  if [[ -n "$ide_port" ]]; then
    "$wc" auto --project "$out" --trust-project --port "$ide_port" --auto-port "$auto_port"
  else
    "$wc" auto --project "$out" --trust-project --auto-port "$auto_port"
  fi
}

cmd_handoff() {
  local dir out appid
  dir="$(project_dir "$1")"
  out="$(miniapp_project_dir "$dir")"
  appid="$(miniapp_appid "$out")"

  cat <<EOF
current_appid=${appid:-missing}
miniapp_project=$out

Need from user:
1. Open https://mp.weixin.qq.com/ and log in to the target Mini Program account.
2. Find the Mini Program AppID in the public-platform development settings.
3. Send only the AppID value that looks like wx + 16 hex characters, for example wx1234567890abcdef.
4. Do not send AppSecret, private keys, cookies, QR screenshots, or verification codes.
5. Make sure the WeChat account logged in to Developer Tools is an administrator/developer for this Mini Program.

After the user gives AppID, run:
$(script_path) release "$dir" <appid> <version> "<desc>"

If AppID is already bound and only upload is needed, run:
$(script_path) release "$dir" keep <version> "<desc>"
EOF
}

cmd_create_account() {
  cat <<EOF
Goal:
Create a real WeChat Mini Program account, then give Codex only the AppID so Codex can bind, test, and upload.

Open:
https://mp.weixin.qq.com/

User steps:
1. Click the registration entry and choose Mini Program as the account type.
2. Use an email that has not already been bound to another WeChat public-platform/open-platform account.
3. Activate the account from the email sent by WeChat.
4. Choose the subject type that matches the real owner: individual, enterprise, government, media, or other organization.
5. Complete the platform-required real-name, administrator, phone, payment/verification, or qualification steps shown on the page.
6. Fill the Mini Program name, avatar, introduction, service category, and any required business qualification.
7. After the Mini Program account is created, open the development settings and copy the AppID.
8. Send Codex only the AppID value, for example wx1234567890abcdef.

Do not send:
- AppSecret
- account password
- private keys
- cookies
- verification codes
- QR-code screenshots
- identity documents

Then Codex runs:
$(script_path) release /path/to/miniapp <appid> <version> "<desc>"

Notes:
- Individual accounts can be enough for simple tools, demos, and many content/lightweight apps.
- Enterprise or organization accounts are usually needed for business branding, payment-like flows, regulated categories, or formal operation.
- If the page asks for QR scan, identity verification, payment verification, or qualification upload, the user must complete that step directly.
EOF
}

cmd_appid() {
  local dir out appid current
  dir="$(project_dir "$1")"
  out="$(miniapp_project_dir "$dir")"
  appid="${2:-}"
  current="$(miniapp_appid "$out")"

  if [[ -z "$appid" ]]; then
    echo "miniapp_project=$out"
    echo "appid=${current:-missing}"
    if is_real_appid "$current"; then
      echo "upload_appid=ok"
    else
      echo "upload_appid=missing"
      echo "hint: run miniapp_release.sh handoff \"$dir\""
    fi
    return
  fi

  if ! is_real_appid "$appid"; then
    echo "invalid AppID: $appid" >&2
    echo "expected format: wx followed by 16 hex characters, for example wx1234567890abcdef" >&2
    exit 1
  fi

  set_project_appid "$out" "$appid"
  echo "appid_bound=$appid"
  echo "miniapp_project=$out"
}

cmd_upload() {
  local dir version desc out wc info appid private_appid
  dir="$(project_dir "$1")"
  version="${2:-}"
  desc="${3:-}"
  if [[ -z "$version" || -z "$desc" ]]; then
    echo "upload requires <version> and <desc>" >&2
    exit 2
  fi
  out="$(miniapp_project_dir "$dir")"
  wc="$(wechat_cli)"
  appid="$(miniapp_appid "$out")"
  private_appid="$(miniapp_private_appid "$out")"
  if [[ -n "$private_appid" ]]; then
    echo "upload blocked: project.private.config.json contains appid=$private_appid and may override project.config.json. Run miniapp_release.sh appid \"$dir\" <real-appid> to clean it." >&2
    exit 1
  fi
  if [[ -z "$appid" || "$appid" == "touristappid" ]]; then
    echo "upload requires a real AppID in project.config.json; current appid=${appid:-missing}. Use open/check/auto for touristappid projects, then replace AppID before upload." >&2
    exit 1
  fi
  info="$(info_file "$version")"
  "$wc" upload --project "$out" --version "$version" --desc "$desc" --info-output "$info"
  echo "upload_info=$info"
  cat "$info"
}

cmd_release() {
  local dir appid version desc
  dir="$(project_dir "$1")"
  appid="${2:-}"
  version="${3:-}"
  desc="${4:-}"
  if [[ -z "$appid" || -z "$version" || -z "$desc" ]]; then
    echo "release requires <project_dir> <appid|keep> <version> <desc>" >&2
    exit 2
  fi
  if [[ "$appid" != "keep" ]]; then
    cmd_appid "$dir" "$appid"
  fi
  cmd_build "$dir"
  cmd_check "$dir"
  cmd_upload "$dir" "$version" "$desc"
}

cmd_info() {
  local version
  version="${2:-}"
  if [[ -z "$version" ]]; then
    echo "info requires <project_dir> <version>" >&2
    exit 2
  fi
  cat "$(info_file "$version")"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    doctor) cmd_doctor "$@" ;;
    install) cmd_install "$@" ;;
    build) cmd_build "$@" ;;
    check) cmd_check "$@" ;;
    open) cmd_open "$@" ;;
    auto) cmd_auto "$@" ;;
    create-account) cmd_create_account "$@" ;;
    handoff) cmd_handoff "$@" ;;
    appid) cmd_appid "$@" ;;
    upload) cmd_upload "$@" ;;
    release) cmd_release "$@" ;;
    info) cmd_info "$@" ;;
    ""|-h|--help|help) usage ;;
    *) echo "unknown command: $cmd" >&2; usage; exit 2 ;;
  esac
}

main "$@"
