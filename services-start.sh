#!/bin/sh
# ============================================================
#  ASUS RT-AC68U (梅林固件) 开机自启脚本片段 —— cloudflared 部分
#  用法:把下面的 cloudflared 块追加到 /jffs/scripts/services-start
#  然后:  chmod +x /jffs/scripts/services-start
# ============================================================

# ---------- cloudflared 开机自启块 ----------
# 启动 cloudflared(Cloudflare Tunnel)远程访问
if [ -f /jffs/cloudflared-token ] && [ -s /jffs/cloudflared-token ]; then
    if ! pidof cloudflared > /dev/null 2>&1; then
        TOKEN=$(cat /jffs/cloudflared-token)
        /jffs/cloudflared tunnel run --token "$TOKEN" >> /jffs/cloudflared.log 2>&1 &
        echo "started cloudflared pid=$!" >> /jffs/cloudflared.log
    fi
fi

# ---------- 说明 ----------
# 1. 前提: /jffs/cloudflared 已存在且可执行
# 2. 前提: /jffs/cloudflared-token 已写入 token(一行)
# 3. 每次开机: 检查 token 存在且 cloudflared 未运行 -> 启动
# 4. 日志写 /jffs/cloudflared.log,可 tail -20 查看