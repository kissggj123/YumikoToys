#!/usr/bin/env bash
# 独立测试：Cydia 风格进度条
set -euo pipefail

readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly BLUE=$'\033[34m'
readonly CYAN=$'\033[36m'
readonly GRAY=$'\033[90m'
readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'
readonly CLRLINE=$'\033[2K'
readonly PROGRESS_WIDTH=28

progress_bar() {
    local cur="$1" total="$2" label="$3" action="${4:-}"
    local pct=0
    [[ "$total" -gt 0 ]] && pct=$(( cur * 100 / total ))
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

progress_done() {
    local total_sec="${1:-}" label="${2:-完成}" bar="" i
    for (( i=0; i<PROGRESS_WIDTH; i++ )); do bar+="="; done
    local tstr=""
    [[ -n "$total_sec" ]] && tstr="  ${GRAY}（用时 ${total_sec}s）${RESET}"
    printf "\r${CLRLINE}  ${GREEN}✓${RESET} ${BOLD}%s${RESET}  [${GREEN}%s${RESET}] ${BOLD}100%%${RESET}${tstr}\n" \
        "$label" "$bar"
}

SPINNER_PID=""
spinner_chars='|/-\'

spinner_start() {
    local label="$1"
    (
        local i=0
        while :; do
            local ch="${spinner_chars:i%4:1}"
            printf "\r${CLRLINE}  ${CYAN}▸${RESET} ${BOLD}%s${RESET}  ${GREEN}[%s]${RESET}" "$label" "$ch"
            i=$((i+1))
            sleep 0.15
        done
    ) &
    SPINNER_PID=$!
}

spinner_stop() {
    local label="${1:-完成}"
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    printf "\r${CLRLINE}  ${GREEN}✓${RESET} ${BOLD}%s${RESET}\n" "$label"
}

echo ""
echo "=== progress_bar（0→100）==="
for i in $(seq 0 100); do
    progress_bar "$i" 100 "解析 Swift Package" "依赖 $i"
    sleep 0.02
done
echo ""

echo ""
echo "=== 关键百分比点 ==="
for pct in 0 5 15 33 50 75 90 100; do
    progress_bar "$pct" 100 "编译目标" "Phase ${pct}/100"
    sleep 0.3
done
echo ""
echo ""

echo "=== progress_done 完成态 ==="
progress_done "42.3" "构建完成"

echo ""
echo "=== spinner（3 秒）==="
spinner_start "正在验证签名…"
sleep 3
spinner_stop "验证通过"

echo ""
echo "=== 多阶段模拟 ==="
stages=( "解析依赖" "编译目标" "代码签名" "验证" )
total_stages=${#stages[@]}
for idx in "${!stages[@]}"; do
    # 阶段内做 0→100% 的小动画
    for i in $(seq 0 100); do
        progress_bar "$(( idx * 100 + i ))" "$(( total_stages * 100 ))" \
            "构建阶段 $((idx+1))/$total_stages" "${stages[$idx]}"
        sleep 0.01
    done
done
echo ""
progress_done "18.7" "全部完成"
echo ""
