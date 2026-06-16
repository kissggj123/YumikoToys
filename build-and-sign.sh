#!/usr/bin/env bash
#
# build-and-sign.sh
#
# 用途：一键构建 YumikoToys macOS App + Widget Extension，并正确地把
#       entitlements（App Group / UserNotifications 等）嵌到签名里，
#       避免用 `codesign --deep` 丢 capability 导致 Widget 读不到同步数据。
#
# 使用：
#   1) 把脚本放到项目根目录（即 YumikoToys.xcodeproj 所在目录）
#   2) chmod +x build-and-sign.sh
#   3) ./build-and-sign.sh                 # 使用默认证书（脚本会挑第一个 Apple Development）
#      ./build-and-sign.sh "BunnyCC_Days"   # 使用你自己的证书名
#      CODESIGN_IDENTITY="BunnyCC_Days" CONFIGURATION=Release ./build-and-sign.sh
#
# 环境变量（可覆盖）：
#   PROJECT_FILE       默认 YumikoToys.xcodeproj
#   SCHEME             默认 YumikoToys
#   CONFIGURATION      默认 Release
#   SDK                默认 macosx
#   CODESIGN_IDENTITY  签名证书（可用 `security find-identity -v -p codesigning` 查看）
#   DERIVED_DATA_DIR   构建产物目录，默认 ./build
#
# 输出：
#   ${DERIVED_DATA_DIR}/${CONFIGURATION}/YumikoToys.app  —— 已签名的 App Bundle
#
# 验证方式：
#   codesign -dvv "build/Release/YumikoToys.app"
#   codesign -d --entitlements :- "build/Release/YumikoToys.app/Contents/MacOS/YumikoToys" \
#       | plutil -p -
#   # 应该能看到 application-groups: [ "group.com.Lite.YumikoToys" ]
#

set -euo pipefail

# --------------------------------------------------------------------------
# 常量 / 颜色
# --------------------------------------------------------------------------
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'

log_info()  { echo -e "${BOLD}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[FAIL]${RESET}  $*" 1>&2; }

fail() { log_error "$*"; exit 1; }

# --------------------------------------------------------------------------
# 参数解析
# --------------------------------------------------------------------------
PROJECT_FILE="${PROJECT_FILE:-YumikoToys.xcodeproj}"
SCHEME="${SCHEME:-YumikoToys}"
CONFIGURATION="${CONFIGURATION:-Release}"
SDK="${SDK:-macosx}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-./build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

# --------------------------------------------------------------------------
# 命令行参数解析（支持位置参数 / --debug / --release / --cert）
#   ./build-and-sign.sh debug                     # Debug + 自动选证书
#   ./build-and-sign.sh release "BunnyCC_Days"    # Release + 指定证书
#   ./build-and-sign.sh --debug --cert "BunnyCC_Days"
# --------------------------------------------------------------------------
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug|debug|Debug)
            CONFIGURATION=Debug; shift ;;
        -r|--release|release|Release)
            CONFIGURATION=Release; shift ;;
        --cert)
            CODESIGN_IDENTITY="$2"; shift 2 ;;
        --cert=*)
            CODESIGN_IDENTITY="${1#*=}"; shift ;;
        *)
            POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"

# 位置参数：若还剩一个，当作签名证书；若剩两个，依次为 configuration + 证书
if [[ $# -ge 1 ]]; then
    lower1=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$lower1" in
        debug)   CONFIGURATION=Debug; shift ;;
        release) CONFIGURATION=Release; shift ;;
        *)       CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-$1}"; shift ;;
    esac
fi
[[ $# -ge 1 && -z "$CODESIGN_IDENTITY" ]] && CODESIGN_IDENTITY="$1"
[[ $# -ge 2 ]] && CODESIGN_IDENTITY="$2"

# --------------------------------------------------------------------------
# 前置检查
# --------------------------------------------------------------------------
cd "$(dirname "$0")"
[[ -f "$PROJECT_FILE/project.pbxproj" ]] || fail "找不到项目文件：$(pwd)/$PROJECT_FILE"

if ! command -v xcodebuild >/dev/null 2>&1; then
    fail "未安装 xcodebuild，请先安装 Xcode 或运行 xcode-select --install"
fi

# 列出可用的 codesign 证书，给用户参考
log_info "可用的 codesign 证书："
security find-identity -v -p codesigning 2>/dev/null | sed 's/^/  /' | head -15

if [[ -z "$CODESIGN_IDENTITY" ]]; then
    CODESIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -E '"Apple Development|Developer ID Application|Mac Developer"' \
        | head -1 | sed -E 's/.*"(.+)".*/\1/')
    [[ -n "$CODESIGN_IDENTITY" ]] || fail "未找到可用签名证书；请传入 CODESIGN_IDENTITY=xxx 或第一个参数"
    log_warn "未指定 CODESIGN_IDENTITY，自动选择：${CODESIGN_IDENTITY}"
else
    log_ok "使用签名证书：${CODESIGN_IDENTITY}"
fi

# --------------------------------------------------------------------------
# 构建
# --------------------------------------------------------------------------
log_info "开始构建：scheme=${SCHEME}  configuration=${CONFIGURATION}"
log_info "输出目录：$(pwd)/${DERIVED_DATA_DIR}"

rm -rf "${DERIVED_DATA_DIR}/${CONFIGURATION}"
mkdir -p "${DERIVED_DATA_DIR}"

# 1) 先解析 Swift Package 依赖（把 checkouts 拉下来）
log_info "解析 Swift Package 依赖..."
xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme  "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGN_STYLE=None CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    resolvePackageDependencies >"${DERIVED_DATA_DIR}/resolve.log" 2>&1 || true

# 2) 确保本地 Splash 包存在（ThirdParty/Splash）
#    SplashImageGen 缺 `import CoreGraphics`，我们已经把它克隆到项目仓库的
#    ThirdParty/Splash，并在 CGImage+WriteToURL.swift 里补上了 import CoreGraphics。
#    project.pbxproj 里 Splash 的 repositoryURL 已指向这个本地路径。
LOCAL_SPLASH="${PROJECT_ROOT:-$(pwd)}/ThirdParty/Splash"
TARGET_SWIFT_FILE="${LOCAL_SPLASH}/Sources/SplashImageGen/Extensions/CGImage+WriteToURL.swift"

if [ ! -d "$LOCAL_SPLASH" ]; then
    log_warn "未找到本地 Splash 包：$LOCAL_SPLASH"
    log_warn "正在自动克隆并打补丁..."
    mkdir -p ThirdParty
    rm -rf "$LOCAL_SPLASH"
    git clone --depth 1 https://github.com/JohnSundell/Splash.git "$LOCAL_SPLASH" >/dev/null 2>&1
fi

if [ -f "$TARGET_SWIFT_FILE" ]; then
    if ! grep -q "import CoreGraphics" "$TARGET_SWIFT_FILE"; then
        log_info "在本地 Splash 中补上 import CoreGraphics"
        sed -i '' -E 's/^([[:space:]]*import[[:space:]]+Foundation)$/\1\'$'\n''import CoreGraphics/' "$TARGET_SWIFT_FILE"
        # 兜底：若 sed 没匹配上，就在文件开头加一行
        if ! grep -q "^import CoreGraphics$" "$TARGET_SWIFT_FILE"; then
            { echo 'import CoreGraphics'; echo ''; cat "$TARGET_SWIFT_FILE"; } > "${TARGET_SWIFT_FILE}.tmp" && mv "${TARGET_SWIFT_FILE}.tmp" "$TARGET_SWIFT_FILE"
        fi
        log_ok "本地 Splash 补丁完成"
    fi
else
    log_warn "未找到 $TARGET_SWIFT_FILE（请确认本地 Splash 包版本）"
fi

# 3) 正式构建（通过 xcpretty 美化输出，同时保留完整原始日志）
if command -v xcpretty >/dev/null 2>&1; then
    set -o pipefail
    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme  "${SCHEME}" \
        -sdk     "${SDK}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        CODE_SIGN_STYLE=None \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_AUTOMATICALLY=NO \
        DEVELOPMENT_TEAM="" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        ENABLE_HARDENED_RUNTIME=NO \
        build 2>&1 | tee "${DERIVED_DATA_DIR}/build.log" | xcpretty --color
    BUILD_RC=${PIPESTATUS[0]}
    set +o pipefail
else
    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme  "${SCHEME}" \
        -sdk     "${SDK}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        CODE_SIGN_STYLE=None \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_AUTOMATICALLY=NO \
        DEVELOPMENT_TEAM="" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        ENABLE_HARDENED_RUNTIME=NO \
        build 2>&1 | tee "${DERIVED_DATA_DIR}/build.log"
    BUILD_RC=$?
fi

# 如果构建失败，把原始日志末尾再拉一次出来（xcpretty 会吞掉 error 上下文）
APP_PATH="${DERIVED_DATA_DIR}/${CONFIGURATION}/YumikoToys.app"
if [[ $BUILD_RC -ne 0 || ! -d "$APP_PATH" ]]; then
    echo
    log_warn "—— 原始错误上下文 ——"
    grep -B2 -A10 -E "(error:|BUILD FAILED)" "${DERIVED_DATA_DIR}/build.log" 2>/dev/null | head -50 || true
    fail "构建失败（exit=${BUILD_RC}）。完整日志：${DERIVED_DATA_DIR}/build.log"
fi
log_ok "构建完成：${APP_PATH}"

# --------------------------------------------------------------------------
# 签名（关键：必须带 --entitlements，且先签 appex 再签主 app）
# --------------------------------------------------------------------------
sign_bundle() {
    local bundle="$1"
    local entitlements="$2"

    [[ -d "$bundle" ]] || { log_warn "跳过不存在的 bundle：$bundle"; return 0; }

    if [[ -f "$entitlements" ]]; then
        log_info "签名 $(basename "$bundle") 并嵌入 entitlements：$(basename "$entitlements")"
        codesign --force --sign "${CODESIGN_IDENTITY}" \
                 --entitlements "$entitlements" \
                 --timestamp=none \
                 "$bundle"
    else
        log_warn "entitlements 文件不存在：$entitlements —— 将不带 entitlement 签名"
        codesign --force --sign "${CODESIGN_IDENTITY}" \
                 --timestamp=none \
                 "$bundle"
    fi
}

# 按嵌套顺序由内到外签名：先 sign Helper / appex，最后签主 App
# 1) 查找 Widget Extension
APPEX_DIR="${APP_PATH}/Contents/PlugIns"
if [[ -d "$APPEX_DIR" ]]; then
    for appex in "$APPEX_DIR"/*.appex; do
        [[ -d "$appex" ]] || continue
        APPEX_PLIST="$appex/Contents/Info.plist"
        APPEX_ENTITLEMENTS="$appex/Contents/embedded.plist"
        # 如果没嵌进去（首次构建通常没有），就用源代码里的那份
        if [[ ! -f "$APPEX_ENTITLEMENTS" ]]; then
            APPEX_ENTITLEMENTS="$(pwd)/YumikoWidget/YumikoWidget.entitlements"
        fi
        sign_bundle "$appex" "$APPEX_ENTITLEMENTS"
    done
fi

# 2) 查找嵌套的 Helper（如果有）
HELPER_DIR="${APP_PATH}/Contents/Library/LoginItems"
if [[ -d "$HELPER_DIR" ]]; then
    for helper in "$HELPER_DIR"/*.app; do
        [[ -d "$helper" ]] || continue
        HELPER_ENTITLEMENTS="$helper/Contents/embedded.plist"
        if [[ ! -f "$HELPER_ENTITLEMENTS" ]]; then
            HELPER_ENTITLEMENTS="$(pwd)/YumikoToysHelper/YumikoToysHelper.entitlements"
        fi
        sign_bundle "$helper" "$HELPER_ENTITLEMENTS"
    done
fi

# 3) 主 App
MAIN_ENTITLEMENTS="${APP_PATH}/Contents/embedded.plist"
if [[ ! -f "$MAIN_ENTITLEMENTS" ]]; then
    MAIN_ENTITLEMENTS="$(pwd)/YumikoToys/Assets/YumikoToys.entitlements"
fi
sign_bundle "$APP_PATH" "$MAIN_ENTITLEMENTS"

log_ok "所有 bundle 签名完成"

# --------------------------------------------------------------------------
# 验证
# --------------------------------------------------------------------------
log_info "——— 签名验证 ———"
codesign -dvv "$APP_PATH" 2>&1 | head -15
echo
log_info "主 App entitlements（二进制里的）"
codesign -d --entitlements :- "$APP_PATH/Contents/MacOS/YumikoToys" 2>/dev/null \
    | plutil -p - 2>/dev/null | sed 's/^/  /' || log_warn "无法抽取 entitlements"

if [[ -d "$APPEX_DIR" ]]; then
    for appex in "$APPEX_DIR"/*.appex; do
        [[ -d "$appex" ]] || continue
        APPEX_BIN="$appex/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$appex/Contents/Info.plist" 2>/dev/null || echo YumikoWidget)"
        log_info "Widget Extension entitlements（$(basename "$appex")）"
        codesign -d --entitlements :- "$APPEX_BIN" 2>/dev/null \
            | plutil -p - 2>/dev/null | sed 's/^/  /' || true
    done
fi

# --------------------------------------------------------------------------
# 结束
# --------------------------------------------------------------------------
echo
log_ok "全部完成 ✅"
log_info "可直接双击运行：${APP_PATH}"
log_info "或：open ${APP_PATH}"
