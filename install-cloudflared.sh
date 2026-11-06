#!/bin/sh
# ============================================================
#  一键在 ASUS RT-AC68U(或同类梅林固件路由器)安装 cloudflared
#  运行:  sh install-cloudflared.sh
#  要求:  已在 Cloudflare 后台创建 Tunnel 并拿到 token
# ============================================================

# ---- 配置区(按需修改) ----
ARCH=arm                # 架构: arm / arm64 / amd64 (由 uname -m 决定)
INSTALL_DIR=/jffs       # 安装目录(持久化,重启不丢)
TOKEN_FILE=/jffs/cloudflared-token
# 若 token 不在环境变量里,脚本会提示你手动写入 TOKEN_FILE
# 可用:  export CF_TUNNEL_TOKEN="eyJhIjoi..."
# ============================================================

# 自动判断架构(若未手动指定)
if [ -z "$ARCH_AUTO" ]; then
    M=$(uname -m)
    case "$M" in
        armv7*|arm*) ARCH=arm ;;
        aarch64|arm64) ARCH=arm64 ;;
        x86_64|amd64) ARCH=amd64 ;;
        *) echo "未知架构: $M,请手动设 ARCH"; exit 1 ;;
    esac
fi

URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
BIN="${INSTALL_DIR}/cloudflared"

echo "==> 下载 cloudflared (${ARCH}) ..."
if ! wget -O "$BIN" "$URL"; then
    echo "下载失败,请检查网络"; exit 1
fi
chmod +x "$BIN"
echo "   版本: $($BIN --version)"

# 处理 token
if [ -n "$CF_TUNNEL_TOKEN" ]; then
    echo "$CF_TUNNEL_TOKEN" > "$TOKEN_FILE"
    echo "==> token 已写入 $TOKEN_FILE"
elif [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    echo "==> 使用已有 token: $TOKEN_FILE"
else
    echo ""
    echo "!! 尚未配置 token。请先:"
    echo "   1. 在 https://one.dash.cloudflare.com 创建 Tunnel 拿 token"
    echo "   2. 把 token 写入:  echo '你的token' > $TOKEN_FILE"
    echo ""
fi

# 首次启动测试
if [ -s "$TOKEN_FILE" ]; then
    echo "==> 启动并测试连接 ..."
    killall cloudflared 2>/dev/null
    "$BIN" tunnel run --token "$(cat "$TOKEN_FILE")" > "${INSTALL_DIR}/cloudflared.log" 2>&1 &
    sleep 12
    echo "==> 日志:"
    tail -8 "${INSTALL_DIR}/cloudflared.log"
    if pidof cloudflared >/dev/null 2>&1; then
        echo "==> cloudflared 运行中 (pid=$(pidof cloudflared))"
    else
        echo "==> cloudflared 未运行,请检查上面日志"
    fi
fi

echo ""
echo "完成。开机自启请把 services-start.sh 的内容追加到 /jffs/scripts/services-start"