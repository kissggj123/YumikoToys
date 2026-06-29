#!/usr/bin/env bash
#
# diagnose.sh — 诊断 YumikoToys.app 闪退 + 采集系统日志
#
# 改进：
#   1) 保留原有的签名 / entitlements / 包结构检查
#   2) 启动应用后等待 60 秒，让你点击按钮触发闪退
#   3) 同步采集：
#      - 进程 stdout/stderr
#      - `log show --predicate '...' --last 90s` (系统统一日志)
#      - ~/Library/Logs/DiagnosticReports/ 中新生成的 crash report
#   4) 所有日志存到 ./build/diagnose-<时间戳>/ 下
#

set -u

# ---------- 常量 / 颜色 ----------
readonly BOLD=$'\033[1m'
readonly GREEN=$'\033[32m'
readonly RED=$'\033[31m'
readonly YELLOW=$'\033[33m'
readonly RESET=$'\033[0m'

ok()      { printf "  ${GREEN}[ OK ]${RESET} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}[WARN]${RESET} %s\n" "$*"; }
fail()    { printf "  ${RED}[FAIL]${RESET} %s\n" "$*"; }
section() { printf "\n${BOLD}▸ %s${RESET}\n" "$*"; }

APP_PATH="${1:-./build/Build/Products/Debug/YumikoToys.app}"
WAIT_SECONDS="${WAIT_SECONDS:-60}"

# 日志目录（留档方便复盘）
TS=$(date '+%Y%m%d-%H%M%S')
LOG_DIR="./build/diagnose-${TS}"
mkdir -p "${LOG_DIR}"

printf "${BOLD}YumikoToys.app 诊断（v2 — 长时间运行 + 系统日志）${RESET}\n"
printf "  目标 App      : %s\n" "$APP_PATH"
printf "  启动后等待    : %s 秒（这段时间请在界面上操作，点击会闪退的按钮）\n" "$WAIT_SECONDS"
printf "  日志输出目录  : %s\n" "$LOG_DIR"
printf "  开始时间      : %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

if [[ ! -d "$APP_PATH" ]]; then
    fail ".app 不存在：$APP_PATH"
    exit 1
fi

CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
PLIST="$CONTENTS/Info.plist"
PLUGINS="$CONTENTS/PlugIns"
LOGIN_HELPERS="$CONTENTS/Library/LoginItems"
EXEC_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || echo "YumikoToys")
BIN="$MACOS/$EXEC_NAME"

# ============================================================
# 1) 包结构 + 签名 + entitlements 快速检查（这次只做摘要）
# ============================================================
section "1/5  签名 / entitlements 快速检查"

if codesign -v "$APP_PATH" 2>&1; then
    ok "codesign -v 通过"
else
    warn "codesign -v 失败"
fi

AUTH=$(codesign -dv "$APP_PATH" 2>&1 | grep -E '^Authority=' | head -1 | sed 's/^Authority=//')
ok "签名 Authority: ${AUTH:-<unsigned>}"

TEAM_ID=$(codesign -dv "$APP_PATH" 2>&1 | grep -E '^TeamIdentifier=' | sed 's/^TeamIdentifier=//')
ok "TeamIdentifier: ${TEAM_ID:-<empty>}"

ENT_OUT=$(codesign -d --entitlements :- "$BIN" 2>/dev/null)
if [[ -n "$ENT_OUT" ]]; then
    ok "entitlements 已嵌入，内容："
    echo "$ENT_OUT" | plutil -p - 2>/dev/null | sed 's/^/    /'
else
    warn "无法抽取 entitlements（可能签名无效或二进制损坏）"
fi

# ============================================================
# 2) 清 quarantine，再用 open 启动 app（保持进程存活）
# ============================================================
section "2/5  启动 App"

xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

# 记录启动时间，后面捞系统日志用
START_TS=$(date -u '+%Y-%m-%d %H:%M:%S %z')
echo "  启动时刻: $START_TS"

# 用 `open` 启动，同时在后台保留进程追踪
APP_STDOUT="${LOG_DIR}/app-stdout.log"
APP_STDERR="${LOG_DIR}/app-stderr.log"

# 后台跑 open（open 默认会返回，但 app 自己会运行），同时我们把可执行文件直接在后台起一份以捕获 stdout/stderr
"$BIN" > "$APP_STDOUT" 2> "$APP_STDERR" &
APP_PID=$!
echo "  已启动 App，PID = $APP_PID"
echo "  ${BOLD}请在 ${WAIT_SECONDS} 秒内去界面上操作：点击会闪退的按钮。${RESET}"
echo "  如果 app 自己闪退，我们会捕获退出码 + crash report"

# ============================================================
# 3) 等待 & 监控进程
# ============================================================
section "3/5  等待 ${WAIT_SECONDS} 秒（可操作 UI 触发闪退）"

ELAPSED=0
CHECK_INTERVAL=5
CRASHED=0
EXIT_CODE="still-running"

while [[ $ELAPSED -lt $WAIT_SECONDS ]]; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        # 进程已死，抓退出码
        wait "$APP_PID" 2>/dev/null
        EXIT_CODE=$?
        CRASHED=1
        printf "\n  ${RED}[!] 进程已退出（exit = %s）${RESET}\n" "$EXIT_CODE"
        break
    fi
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
    printf "  … %d 秒\n" "$ELAPSED"
done

if [[ $CRASHED -eq 0 ]]; then
    # 进程仍在 → 正常杀掉
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
    printf "\n  ${GREEN}[✓] 等待结束，进程仍在运行（未自行闪退）${RESET}\n"
fi

# ============================================================
# 4) 采集系统日志 & crash 报告
# ============================================================
section "4/5  采集系统日志"

SYS_LOG="${LOG_DIR}/system-unified-log.log"
echo "  统一日志（最近 90s，过滤 YumikoToys 相关）→ $SYS_LOG"
log show --last 90s \
    --predicate 'process == "YumikoToys" OR process == "YumikoWidget" OR processImagePath CONTAINS[c] "YumikoToys" OR message CONTAINS[c] "YumikoToys"' \
    --style compact > "$SYS_LOG" 2>&1 || true

SYS_LOG_ERRORS="${LOG_DIR}/system-error-fault.log"
echo "  仅 error/fault 级 → $SYS_LOG_ERRORS"
log show --last 90s \
    --predicate '(process == "YumikoToys" OR processImagePath CONTAINS[c] "YumikoToys") AND (eventType == "logEvent" AND (messageType == "Error" OR messageType == "Fault"))' \
    --style compact > "$SYS_LOG_ERRORS" 2>&1 || true

# 找 ~/Library/Logs/DiagnosticReports/ 里在本次启动时间之后生成的 crash report
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
CRASH_MATCH="${LOG_DIR}/crash-reports.txt"
echo "" > "$CRASH_MATCH"

if [[ -d "$CRASH_DIR" ]]; then
    # 找启动时间之后 mtime 的文件
    while IFS= read -r -d '' f; do
        echo "=== $(basename "$f") ===" >> "$CRASH_MATCH"
        head -n 80 "$f" >> "$CRASH_MATCH" 2>/dev/null || true
        echo "" >> "$CRASH_MATCH"
    done < <(find "$CRASH_DIR" -maxdepth 1 -type f \( -name "YumikoToys*" -o -name "YumikoWidget*" \) -newer "$APP_STDOUT" -print0 2>/dev/null)
fi

# ============================================================
# 5) 汇总打印
# ============================================================
section "5/5  日志摘要"

echo ""
echo "  进程 stdout / stderr 输出："
if [[ -s "$APP_STDOUT" ]]; then
    echo "  --- stdout （前 80 行）---"
    sed 's/^/    /' "$APP_STDOUT" | head -n 80
fi
if [[ -s "$APP_STDERR" ]]; then
    echo "  --- stderr （前 80 行）---"
    sed 's/^/    /' "$APP_STDERR" | head -n 80
fi
if [[ ! -s "$APP_STDOUT" && ! -s "$APP_STDERR" ]]; then
    echo "    （无 stdout/stderr 输出 — macOS GUI app 默认没有 stdout，闪退信息一般在 crash report 或系统日志）"
fi

echo ""
echo "  系统日志 - 仅 Error/Fault（前 120 行）："
if [[ -s "$SYS_LOG_ERRORS" ]]; then
    sed 's/^/    /' "$SYS_LOG_ERRORS" | head -n 120
else
    echo "    （空）"
fi

echo ""
echo "  Crash 报告（~/Library/Logs/DiagnosticReports/）："
if [[ -s "$CRASH_MATCH" ]]; then
    sed 's/^/    /' "$CRASH_MATCH" | head -n 200
else
    echo "    （未发现与本次启动相关的 crash report — 若确实闪退了，请查看 Crash 分类里的文件）"
fi

echo ""
echo "${BOLD}——————————————————————————————————${RESET}"
echo "  日志存档：$LOG_DIR"
echo "  请把下面文件的内容贴给我："
echo "    1) $SYS_LOG_ERRORS（系统 error/fault 日志，最关键）"
echo "    2) $CRASH_MATCH（crash report，如存在）"
echo "    3) $APP_STDERR（stderr）"
echo "  或直接跑："
echo "    cat '$SYS_LOG_ERRORS'"
echo "    cat '$CRASH_MATCH'"
echo "${BOLD}——————————————————————————————————${RESET}"
