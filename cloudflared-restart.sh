#!/bin/sh
# ============================================================
#  cloudflared 常用运维脚本
#  用法:
#    sh cloudflared-restart.sh         # 重启 cloudflared
#    sh cloudflared-restart.sh status  # 查看状态
#    sh cloudflared-restart.sh start   # 启动
#    sh cloudflared-restart.sh stop    # 停止
# ============================================================

BIN=/jffs/cloudflared
TOKEN_FILE=/jffs/cloudflared-token
LOG=/jffs/cloudflared.log

case "$1" in
    status)
        if pidof cloudflared >/dev/null 2>&1; then
            echo "cloudflared RUNNING (pid=$(pidof cloudflared))"
        else
            echo "cloudflared NOT RUNNING"
        fi
        echo "--- log tail ---"
        tail -10 "$LOG" 2>/dev/null
        ;;
    stop)
        killall cloudflared 2>/dev/null
        echo "stopped cloudflared"
        ;;
    start)
        if [ ! -s "$TOKEN_FILE" ]; then echo "token file empty: $TOKEN_FILE"; exit 1; fi
        "$BIN" tunnel run --token "$(cat "$TOKEN_FILE")" >> "$LOG" 2>&1 &
        echo "started cloudflared pid=$!"
        sleep 3
        pidof cloudflared || echo "WARN: not running after start, check $LOG"
        ;;
    restart|*)
        killall cloudflared 2>/dev/null
        sleep 1
        if [ ! -s "$TOKEN_FILE" ]; then echo "token file empty: $TOKEN_FILE"; exit 1; fi
        "$BIN" tunnel run --token "$(cat "$TOKEN_FILE")" >> "$LOG" 2>&1 &
        echo "restarted cloudflared pid=$!"
        sleep 12
        echo "--- log tail ---"
        tail -8 "$LOG"
        pidof cloudflared || echo "WARN: not running, check $LOG"
        ;;
esac