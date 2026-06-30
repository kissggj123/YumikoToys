#!/usr/bin/env bash
#
# build-and-sign.sh
#
# 用途：一键构建 YumikoToys macOS App + Widget Extension，并把 entitlements
#      （App Group / UserNotifications 等）嵌到签名里，避免用 codesign --deep
#       丢 capability 导致 Widget 读不到同步数据。
#
# 用法：
#   ./build-and-sign.sh                    # 进入交互式选单
#   ./build-and-sign.sh auto               # 非交互式：Debug + ad-hoc（适合 CI）
#   ./build-and-sign.sh --clean            # 先 clean 再 build（加在任意组合里）
#   ./build-and-sign.sh release --cert "Apple Development: xxx (TEAMID)"
#   CONFIGURATION=Release CODESIGN_IDENTITY="-" DO_CLEAN=1 ./build-and-sign.sh
#
# 常用参数：
#   debug / release         # 指定构建配置（可省略，会走选单或默认 Debug）
#   --cert "证书名" 或 --cert=-   # 指定签名证书 / ad-hoc
#   --clean / -c / clean    # 先执行 xcodebuild clean 再 build
#   auto / -y / --auto      # 跳过交互，直接 Debug + ad-hoc
#
# 签名策略（交互式会让你选）：
#   1) Apple ID / Developer ID 证书 — 正式签名，可公证分发
#   2) 本地自签名证书        — 自己生成的证书，长期可用
#   3) ad-hoc (-)           — 匿名签名，本地测试，跳过 Gatekeeper
#

set -euo pipefail

# --------------------------------------------------------------------------
# 常量 / 颜色（Cydia 风格进度条）
# --------------------------------------------------------------------------
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly BLUE=$'\033[34m'
readonly CYAN=$'\033[36m'
readonly WHITE=$'\033[37m'
readonly GRAY=$'\033[90m'
readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'
readonly CLRLINE=$'\033[2K'   # 清除整行（ANSI CSI 2K）

# --------------------------------------------------------------------------
# 日志函数
# --------------------------------------------------------------------------
log_info()  { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[FAIL]${RESET}  $*" 1>&2; }
fail()      { log_error "$*"; exit 1; }

# --------------------------------------------------------------------------
# 进度条 / spinner（Cydia 风格）
#
# 视觉效果：
#   ▸ 正在解析 Swift Package...  [\]      ← spinner 模式（未知总进度）
#   ▸ 正在编译目标...  [==========>     ]  52%  CompileSwiftSources
#   ▸ 正在签名...    [================> ]  88%  YumikoWidget.appex
#   ✓ 构建完成 ✅  [====================] 100%  用时 42.3s
#
# 用法：
#   progress_bar <current> <total> <label>        # 打印一行进度条（原地刷新）
#   progress_done <total> <label>                  # 打印 100% 完成（带对勾）
#   spinner_start <label>                          # 启动后台 spinner
#   spinner_stop <exit_code>                       # 停止后台 spinner，显示 OK/FAIL
# --------------------------------------------------------------------------

# 进度条宽度（字符数）
readonly PROGRESS_WIDTH=28

# progress_bar：画一条带百分比的进度条（原地刷新）
#   $1  当前索引  $2  总索引  $3  阶段标签  $4  当前动作（可选）
progress_bar() {
    # 强转为正整数（去掉任何非数字字符，防止 ANSI/中文混入会导致 $((...)) 崩）
    local cur total
    cur=$(printf '%s' "$1" 2>/dev/null | tr -cd '0-9')
    total=$(printf '%s' "$2" 2>/dev/null | tr -cd '0-9')
    [[ -z "$cur" ]]   && cur=0
    [[ -z "$total" ]] && total=0
    # 防除零
    [[ "$total" -eq 0 ]] && total=1

    local label="$3"
    local action="${4:-}"
    local pct=$(( cur * 100 / total ))
    [[ "$pct" -gt 100 ]] && pct=100

    local filled=$(( cur * PROGRESS_WIDTH / total ))
    [[ "$filled" -gt "$PROGRESS_WIDTH" ]] && filled=$PROGRESS_WIDTH
    local bar="" i
    for (( i=0; i<filled; i++ )); do bar+="="; done
    if [[ "$pct" -lt 100 && "$filled" -gt 0 && "$filled" -lt "$PROGRESS_WIDTH" ]]; then
        bar="${bar%=}>"
    fi
    local remain=$(( PROGRESS_WIDTH - filled )) pad=""
    for (( i=0; i<remain; i++ )); do pad+=" "; done

    if [[ -n "$action" ]]; then
        printf "\r${CLRLINE}  ${CYAN}▸${RESET} ${BOLD}%s${RESET}  [${GREEN}%s%s${RESET}] ${BOLD}%3d%%${RESET}  ${GRAY}%s${RESET}" \
            "$label" "$bar" "$pad" "$pct" "$action"
    else
        printf "\r${CLRLINE}  ${CYAN}▸${RESET} ${BOLD}%s${RESET}  [${GREEN}%s%s${RESET}] ${BOLD}%3d%%${RESET}" \
            "$label" "$bar" "$pad" "$pct"
    fi
}

# progress_done：打印"完成"状态（会换行，带对勾）
#   $1  用时（秒，可选）  $2  标签（可选）
progress_done() {
    local total_sec="${1:-}"
    local label="${2:-完成}"
    # 同样强转成纯数字，防 $((...)) 崩溃
    local sec_num
    sec_num=$(printf '%s' "$total_sec" 2>/dev/null | tr -cd '0-9')
    [[ -z "$sec_num" ]] && sec_num=""

    local bar="" i
    for (( i=0; i<PROGRESS_WIDTH; i++ )); do bar+="="; done
    local tstr=""
    if [[ -n "$sec_num" ]]; then
        tstr="  ${GRAY}（用时 ${sec_num}s）${RESET}"
    fi
    printf "\r${CLRLINE}  ${GREEN}✓${RESET} ${BOLD}%s${RESET}  [${GREEN}%s${RESET}] ${BOLD}100%%${RESET}${tstr}\n" \
        "$label" "$bar"
}

# spinner 全局状态
SPINNER_PID=""

spinner_start() {
    local label="$1"
    # 用一个子进程在后台持续刷新 spinner
    (
        local i=0
        local _chars='|/-\'
        while :; do
            local ch="${_chars:i%4:1}"
            printf "\r${CLRLINE}  ${CYAN}▸${RESET} ${BOLD}%s${RESET}  ${GREEN}[%s]${RESET}" "$label" "$ch"
            i=$((i+1))
            sleep 0.15
        done
    ) &
    SPINNER_PID=$!
    trap 'spinner_cleanup' INT TERM EXIT
}

spinner_cleanup() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    printf "\r${CLRLINE}"
}

# spinner_stop <完成后的标签>
# 简化：始终显示绿色 ✓ + 标签；不再区分 exit_code（之前传中文会崩溃）
spinner_stop() {
    local label="${1:-完成}"
    spinner_cleanup
    printf "  ${GREEN}✓${RESET} ${BOLD}%s${RESET}\n" "$label"
}

# 小工具：读取一行用户输入
# 注意：提示信息输出到 stderr，只有返回值发到 stdout
#       这样通过 $(read_choice ...) 调用时，不会把提示文字也捕获到变量里
read_choice() {
    local prompt="$1"
    local default="${2:-}"
    local val
    printf "%s " "$prompt" >&2
    read -r val
    [[ -z "$val" ]] && val="$default"
    printf '%s' "$val"
}

# --------------------------------------------------------------------------
# 证书列表（返回一个数组，带编号）
#  -v  只显示验证通过的
# -p codesigning  只筛选代码签名用途
# --------------------------------------------------------------------------
list_certs() {
    # 典型输入行：
    #   1) AABBCCDDEEFF0011223344  "Apple Development: 2430396170@qq.com (5M55HZ29SU)"
    # awk 处理：
    #   1) 先截掉前缀（数字 + ) + SHA256 + 空白）
    #   2) 再去掉两端的双引号
    #   3) 非空就输出
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -E '^\s*[0-9]+\)' \
        | awk '{
            sub(/^[[:space:]]*[0-9]+\)[[:space:]]*[A-Fa-f0-9]+[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            if (length($0) > 0) print
          }'
}

# 交互式选择证书：
#   1) 先列出系统里所有 codesign 证书（带类型提示）
#   2) 如果没找到，给出 3 个 fallback：手动输入证书名 / 用 ad-hoc / 返回选单
#   3) 用户输入编号 → 设置 IS_ADHOC=0 + CODESIGN_IDENTITY
#   4) 用户输入 "a" → ad-hoc
#   5) 用户输入 "q" → 返回选单
# 返回值：设置全局 IS_ADHOC / CODESIGN_IDENTITY
choose_certificate() {
    echo
    echo -e "${BOLD}▸ 系统中可用的签名证书：${RESET}"
    local certs=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        certs+=("$line")
    done < <(list_certs)

    if [[ ${#certs[@]} -eq 0 ]]; then
        echo "  (没有找到可用于 codesign 的证书。常见原因：)"
        echo "    · Xcode 还没导入过你的 Apple ID 账号（Xcode → Settings → Accounts）"
        echo "    · 钥匙串里的证书没有对应的私钥（被标记为「此证书无效」）"
        echo "    · 你只在 login 钥匙串中安装了证书，但 shell 没有权限读取"
        echo
        echo "  你有三个选择："
        echo "    1) 使用 ad-hoc (-)   —— 本地测试最稳，适合自己用"
        echo "    2) 手动输入证书名   —— 例如：Apple Development: 2430396170@qq.com (5M55HZ29SU)"
        echo "    3) 返回到主选单"
        local sub
        sub=$(read_choice "请输入 [1/2/3]，默认 [1]：" "1")
        case "$sub" in
            2)
                echo
                local manual_name
                manual_name=$(read_choice "请输入证书名称（复制自 Xcode → Signing & Capabilities）：" "")
                if [[ -z "$manual_name" ]]; then
                    log_warn "名称为空，回退到 ad-hoc"
                    IS_ADHOC=1; CODESIGN_IDENTITY="-"
                else
                    IS_ADHOC=0
                    CODESIGN_IDENTITY="$manual_name"
                fi
                ;;
            3)
                IS_ADHOC=3 # 特殊标记：返回选单
                ;;
            1|*)
                IS_ADHOC=1; CODESIGN_IDENTITY="-"
                ;;
        esac
        return
    fi

    # 正常情况：列出所有证书让用户选
    local i=0
    for c in "${certs[@]}"; do
        i=$((i+1))
        local hint=""
        if printf '%s' "$c" | grep -q "Developer ID Application"; then
            hint="  (可公证分发)"
        elif printf '%s' "$c" | grep -q "Apple Development"; then
            hint="  (Apple ID 开发者证书)"
        elif printf '%s' "$c" | grep -q "Mac Developer"; then
            hint="  (旧版 Mac 证书)"
        elif printf '%s' "$c" | grep -q "Apple Distribution"; then
            hint="  (App Store 分发证书)"
        else
            hint="  (自签名 / 其它)"
        fi
        echo "  ${i}) ${c}${hint}"
    done
    echo
    echo "  a) 使用 ad-hoc (-)   —— 不用证书，匿名签名（本地运行最稳）"
    echo "  q) 返回上一级"
    echo
    local idx
    idx=$(read_choice "请输入 [1-${#certs[@]} / a / q]，默认 [1]：" "1")

    if [[ "$idx" == "q" || "$idx" == "Q" ]]; then
        IS_ADHOC=3 # 返回选单
        return
    fi
    if [[ "$idx" == "a" || "$idx" == "A" ]]; then
        IS_ADHOC=1; CODESIGN_IDENTITY="-"
        return
    fi
    if [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$idx" -ge 1 ]] && [[ "$idx" -le ${#certs[@]} ]]; then
        IS_ADHOC=0
        CODESIGN_IDENTITY="${certs[$((idx-1))]}"
        return
    fi
    log_warn "输入无效（$idx），回退到 ad-hoc"
    IS_ADHOC=1; CODESIGN_IDENTITY="-"
}

# --------------------------------------------------------------------------
# 交互式选单
# --------------------------------------------------------------------------
run_menu() {
    # 构建配置（简单，保持不变）
    echo
    echo -e "${BOLD}▸ 选择构建配置${RESET}"
    echo "  1) Debug   — 调试，快速构建，保留调试符号"
    echo "  2) Release — 发布，带优化，适合分发"
    local cfg
    cfg=$(read_choice "请输入 [1/2]，默认 [1]：" "1")
    case "$cfg" in
        2|release|Release|RELEASE) CONFIGURATION=Release ;;
        *)                        CONFIGURATION=Debug   ;;
    esac
    log_info "构建配置 = ${CONFIGURATION}"

    echo
    echo -e "${BOLD}▸ 构建方式${RESET}"
    echo "  1) 增量构建          — 只编译改动的文件，速度快（推荐日常使用）"
    echo "  2) 干净编译 (clean)  — 先清空旧产物再完全重编（推荐第一次构建或遇到莫名错误时）"
    local cl_default
    cl_default="1"
    [[ "$DO_CLEAN" -eq 1 ]] && cl_default="2"   # 命令行已传 --clean，默认选干净编译
    local cl
    cl=$(read_choice "请输入 [1/2]，默认 [${cl_default}]：" "$cl_default")
    case "$cl" in
        2|clean|Clean|CLEAN|c|C) DO_CLEAN=1 ;;
        *)                       DO_CLEAN=0 ;;
    esac
    if [[ "$DO_CLEAN" -eq 1 ]]; then
        log_info "构建方式 = 干净编译（clean + build）"
    else
        log_info "构建方式 = 增量构建"
    fi

    # 签名策略：循环直到用户做出有效选择（支持"返回上一级"）
    while true; do
        echo
        echo -e "${BOLD}▸ 选择签名策略${RESET}"
        echo "  1) 系统中的证书（Apple ID / Developer ID / 自签名证书）"
        echo "     · 会列出钥匙串里所有可用证书，让你挑一个"
        echo "     · 适合正式构建 / 打包发布 / 公证"
        echo "  2) ad-hoc 匿名签名（codesign --sign -，本地双击运行最稳）"
        echo "     · 不依赖任何证书"
        echo "     · 适合本地测试；macOS 允许双击运行"
        echo "  3) 跳过签名（仅构建，稍后自己处理）"
        local sig
        sig=$(read_choice "请输入 [1/2/3]，默认 [2]：" "2")

        case "$sig" in
            1)
                # 进入证书选择子流程
                choose_certificate
                # choose_certificate 返回 IS_ADHOC=3 表示用户要求返回选单
                if [[ "$IS_ADHOC" -eq 3 ]]; then
                    continue
                fi
                break
                ;;
            3)
                IS_ADHOC=2    # 标记：完全不签名
                CODESIGN_IDENTITY=""
                break
                ;;
            2|*)
                IS_ADHOC=1
                CODESIGN_IDENTITY="-"
                break
                ;;
        esac
    done

    # 摘要输出
    if [[ "$IS_ADHOC" -eq 1 ]]; then
        log_ok "使用 ad-hoc 签名（codesign --sign -）"
    elif [[ "$IS_ADHOC" -eq 2 ]]; then
        log_warn "跳过签名，仅做构建"
    else
        log_ok "使用证书：${CODESIGN_IDENTITY}"
    fi

    echo
    echo -e "${BOLD}▸ 确认：${RESET}"
    echo "  构建配置：${CONFIGURATION}"
    if [[ "$DO_CLEAN" -eq 1 ]]; then
        echo "  构建方式：干净编译（先 clean 再 build）"
    else
        echo "  构建方式：增量构建"
    fi
    if [[ "$IS_ADHOC" -eq 1 ]]; then
        echo "  签名方式：ad-hoc (-)"
    elif [[ "$IS_ADHOC" -eq 2 ]]; then
        echo "  签名方式：跳过（仅构建）"
    else
        echo "  签名方式：证书 = ${CODESIGN_IDENTITY}"
    fi
    local go
    go=$(read_choice "按 Enter 开始，输入 n 取消：" "y")
    case "$go" in
        n|N|no|NO|No)
            log_info "已取消"
            exit 0
            ;;
    esac
}

# --------------------------------------------------------------------------
# 参数解析（非交互式入口）
# --------------------------------------------------------------------------
PROJECT_FILE="${PROJECT_FILE:-YumikoToys.xcodeproj}"
SCHEME="${SCHEME:-YumikoToys}"
CONFIGURATION="${CONFIGURATION:-}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-./build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
IS_ADHOC=0
DO_CLEAN=0

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
        clean|--clean|-c)
            DO_CLEAN=1; shift ;;
        auto|--auto|-y)
            AUTO_MODE=1; shift ;;
        *)
            POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
    set -- "${POSITIONAL_ARGS[@]}"
else
    set --
fi

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

# 解析 CODESIGN_IDENTITY → IS_ADHOC 标记
if [[ -n "$CODESIGN_IDENTITY" ]]; then
    _ci_id=$(printf '%s' "$CODESIGN_IDENTITY" | tr '[:upper:]' '[:lower:]')
    if [[ "$_ci_id" == "adhoc" || "$_ci_id" == "--adhoc" || "$CODESIGN_IDENTITY" == "-" ]]; then
        CODESIGN_IDENTITY="-"
        IS_ADHOC=1
    fi
fi

# 决定是否进交互模式
AUTO_MODE="${AUTO_MODE:-0}"
if [[ -z "$CONFIGURATION" || (-z "$CODESIGN_IDENTITY" && "$AUTO_MODE" -eq 0) ]]; then
    if [[ "$AUTO_MODE" -eq 1 ]]; then
        CONFIGURATION="${CONFIGURATION:-Debug}"
        CODESIGN_IDENTITY="-"
        IS_ADHOC=1
        log_info "auto 模式：CONFIGURATION=${CONFIGURATION}，签名=ad-hoc"
    else
        run_menu
    fi
fi

# 兜底
CONFIGURATION="${CONFIGURATION:-Debug}"

# --------------------------------------------------------------------------
# 前置检查
# --------------------------------------------------------------------------
cd "$(dirname "$0")"
[[ -f "$PROJECT_FILE/project.pbxproj" ]] || fail "找不到项目文件：$(pwd)/$PROJECT_FILE"

if ! command -v xcodebuild >/dev/null 2>&1; then
    fail "未安装 xcodebuild，请先安装 Xcode 或运行 xcode-select --install"
fi

# --------------------------------------------------------------------------
# 构建（先 resolve packages，再 build）
# --------------------------------------------------------------------------
log_info "开始构建：scheme=${SCHEME}  configuration=${CONFIGURATION}"
log_info "输出目录：$(pwd)/${DERIVED_DATA_DIR}"

if [[ "$DO_CLEAN" -eq 1 ]]; then
    log_info "[clean] 清空旧构建产物…"
xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme  "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_AUTOMATICALLY=NO \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    clean >"${DERIVED_DATA_DIR}/clean.log" 2>&1 || true
    # 额外把整个 DERIVED_DATA_DIR 清一遍，避免 Swift 模块缓存干扰
    rm -rf "${DERIVED_DATA_DIR}/Build"
fi

rm -rf "${DERIVED_DATA_DIR}/${CONFIGURATION}"
mkdir -p "${DERIVED_DATA_DIR}"

# ==================================================================
# 阶段 1：解析 Swift Package 依赖
# ==================================================================
echo
echo -e "${BOLD}▸ 阶段 1/4：解析 Swift Package${RESET}"
START_T=$(date +%s)
spinner_start "正在拉取 / 解析依赖…"
xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme  "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_AUTOMATICALLY=NO \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    resolvePackageDependencies >"${DERIVED_DATA_DIR}/resolve.log" 2>&1 || true
END_T=$(date +%s)
spinner_stop "解析完成（$((END_T-START_T))s）"

# 确保本地 Splash 补丁已打
LOCAL_SPLASH="$(pwd)/ThirdParty/Splash"
TARGET_SWIFT_FILE="${LOCAL_SPLASH}/Sources/SplashImageGen/Extensions/CGImage+WriteToURL.swift"

if [ -f "$TARGET_SWIFT_FILE" ]; then
    if ! grep -q "import CoreGraphics" "$TARGET_SWIFT_FILE"; then
        echo "  在本地 Splash 中补上 import CoreGraphics"
        sed -i '' -E 's/^([[:space:]]*import[[:space:]]+Foundation)$/\1\'$'\n''import CoreGraphics/' "$TARGET_SWIFT_FILE"
        if ! grep -q "^import CoreGraphics$" "$TARGET_SWIFT_FILE"; then
            { echo 'import CoreGraphics'; echo ''; cat "$TARGET_SWIFT_FILE"; } > "${TARGET_SWIFT_FILE}.tmp" && mv "${TARGET_SWIFT_FILE}.tmp" "$TARGET_SWIFT_FILE"
        fi
    fi
fi

# 阶段 2：编译
# ==================================================================
echo
echo -e "${BOLD}▸ 阶段 2/4：编译${RESET}"
START_T=$(date +%s)

BUILD_LOG="${DERIVED_DATA_DIR}/build.log"
: > "$BUILD_LOG"

# 直接实时输出编译日志（stdout + 留档），不再叠进度条
# CODE_SIGNING_ALLOWED=NO：编译期完全跳过签名，避免 Xcode 要求 provisioning profile
# 签名在阶段 3 由脚本完成
xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme  "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_AUTOMATICALLY=NO \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    ENABLED_HARDENED_RUNTIME=NO \
    build 2>&1 | tee "$BUILD_LOG"
BUILD_RC=${PIPESTATUS[0]}

END_T=$(date +%s)
echo ""
if [[ $BUILD_RC -eq 0 ]]; then
    echo "${GREEN}✓ 编译完成${RESET}  （用时 $((END_T-START_T))s）"
else
    echo "${RED}✗ 编译失败（exit=${BUILD_RC}）${RESET}"
    echo "  ${GRAY}完整日志：${BUILD_LOG}${RESET}"
    fail "编译失败"
fi

APP_PATH_CANDIDATES=(
    "${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${SCHEME}.app"
    "${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/YumikoToys.app"
)
APP_PATH=""
for p in "${APP_PATH_CANDIDATES[@]}"; do
    if [[ -d "$p" ]]; then
        APP_PATH="$p"
        break
    fi
done

if [[ $BUILD_RC -ne 0 || -z "$APP_PATH" ]]; then
    log_warn "—— 原始错误上下文 ——"
    grep -B2 -A10 -E "(error:|BUILD FAILED)" "${DERIVED_DATA_DIR}/build.log" 2>/dev/null | head -50 || true
    echo
    if [[ -z "$APP_PATH" ]]; then
        fail "构建完成但找不到 .app（exit=${BUILD_RC}）"
    else
        fail "构建失败（exit=${BUILD_RC}）。完整日志：${DERIVED_DATA_DIR}/build.log"
    fi
fi
log_ok "构建完成：${APP_PATH}"

# ==================================================================
# 阶段 3：代码签名
# ==================================================================
echo
echo -e "${BOLD}▸ 阶段 3/4：代码签名${RESET}"
START_T=$(date +%s)

sign_bundle() {
    local bundle="$1"
    local entitlements_file="$2"

    [[ -d "$bundle" ]] || return 0

    if [[ "$IS_ADHOC" -eq 2 ]]; then
        return 0  # 完全跳过
    elif [[ "$IS_ADHOC" -eq 1 ]]; then
        if [[ -f "$entitlements_file" ]]; then
            codesign --force --sign - --entitlements "$entitlements_file" "$bundle"
        else
            codesign --force --sign - "$bundle"
        fi
    else
        if [[ -f "$entitlements_file" ]]; then
            codesign --force --sign "${CODESIGN_IDENTITY}" \
                     --entitlements "$entitlements_file" \
                     "$bundle"
        else
            codesign --force --sign "${CODESIGN_IDENTITY}" "$bundle"
        fi
    fi
}

# 先枚举所有需要签名的 bundle（方便做精确进度条）
declare -a SIGN_PATHS=()
declare -a SIGN_ENTITLEMENTS=()
declare -a SIGN_LABELS=()

APPEX_DIR="${APP_PATH}/Contents/PlugIns"
if [[ -d "$APPEX_DIR" ]]; then
    for appex in "$APPEX_DIR"/*.appex; do
        [[ -d "$appex" ]] || continue
        SIGN_PATHS+=("$appex")
        SIGN_ENTITLEMENTS+=("$(pwd)/YumikoWidget/YumikoWidget.entitlements")
        SIGN_LABELS+=("Widget Extension")
    done
fi

HELPER_DIR="${APP_PATH}/Contents/Library/LoginItems"
if [[ -d "$HELPER_DIR" ]]; then
    for helper in "$HELPER_DIR"/*.app; do
        [[ -d "$helper" ]] || continue
        SIGN_PATHS+=("$helper")
        SIGN_ENTITLEMENTS+=("$(pwd)/YumikoToysHelper/YumikoToysHelper.entitlements")
        SIGN_LABELS+=("Login Item Helper")
    done
fi

SIGN_PATHS+=("$APP_PATH")
SIGN_ENTITLEMENTS+=("$(pwd)/YumikoToys/Assets/YumikoToys.entitlements")
SIGN_LABELS+=("主 App")

TOTAL_SIGNS=${#SIGN_PATHS[@]}

# 逐个签名，按索引更新进度条
for i in "${!SIGN_PATHS[@]}"; do
    progress_bar "$i" "$TOTAL_SIGNS" "正在签名" "${SIGN_LABELS[$i]}"
    sign_bundle "${SIGN_PATHS[$i]}" "${SIGN_ENTITLEMENTS[$i]}"
done
progress_bar "$TOTAL_SIGNS" "$TOTAL_SIGNS" "正在签名" "全部完成"

# ad-hoc 需清 quarantine
if [[ "$IS_ADHOC" -eq 1 ]]; then
    xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
fi

END_T=$(date +%s)
progress_done "$((END_T-START_T))" "签名完成（$TOTAL_SIGNS 个 bundle）"

# ==================================================================
# 阶段 4：验证
# ==================================================================
echo
echo -e "${BOLD}▸ 阶段 4/4：验证签名与 entitlements${RESET}"
START_T=$(date +%s)
spinner_start "正在验证代码签名…"

SIGN_VERIFY_LOG="${DERIVED_DATA_DIR}/sign_verify.log"
{
    echo "=== codesign -dvv ==="
    codesign -dvv "$APP_PATH" 2>&1 | head -10
    echo ""
    echo "=== 主 App entitlements（二进制） ==="
    codesign -d --entitlements :- "$APP_PATH/Contents/MacOS/YumikoToys" 2>/dev/null \
        | plutil -p - 2>/dev/null || echo "(无法抽取)"
    if [[ -d "$APPEX_DIR" ]]; then
        for appex in "$APPEX_DIR"/*.appex; do
            [[ -d "$appex" ]] || continue
            APPEX_BIN="$appex/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$appex/Contents/Info.plist" 2>/dev/null || echo YumikoWidget)"
            echo ""
            echo "=== $(basename "$appex") entitlements ==="
            codesign -d --entitlements :- "$APPEX_BIN" 2>/dev/null \
                | plutil -p - 2>/dev/null || echo "(无法抽取)"
        done
    fi
} > "$SIGN_VERIFY_LOG" 2>&1

END_T=$(date +%s)
spinner_stop "验证完成（$((END_T-START_T))s）"

# 输出验证摘要（简洁版，详细内容在日志里）
echo "  ${GRAY}主 App：${GREEN}$(basename "$APP_PATH")${RESET}"
echo "  ${GRAY}签名方式：${GREEN}$(if [[ "$IS_ADHOC" -eq 1 ]]; then echo "ad-hoc"; elif [[ "$IS_ADHOC" -eq 2 ]]; then echo "跳过"; else echo "${CODESIGN_IDENTITY}"; fi)${RESET}"
echo "  ${GRAY}完整验证日志：${RESET}${SIGN_VERIFY_LOG}"

echo
echo -e "${GREEN}${BOLD}✅ 全部完成 ✅${RESET}"
echo "  可直接双击运行：${APP_PATH}"
