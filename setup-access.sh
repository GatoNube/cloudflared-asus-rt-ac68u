#!/bin/sh
# ============================================================
#  用 Cloudflare API 自动给域名加 Access 登录保护
#  自动创建: Access 应用 + "仅我的邮箱"策略
#  用法:
#     export CF_API_TOKEN="..."
#     export CF_ACCOUNT_ID="..."
#     export APP_DOMAIN="router.你的域名.com"
#     export EMAIL="你@example.com"
#     sh setup-access.sh
# ============================================================
set -e

# ---- 配置区(也可用环境变量)----
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}"
APP_DOMAIN="${APP_DOMAIN:-router.你的域名.com}"
APP_NAME="${APP_NAME:-router-access}"
EMAIL="${EMAIL:-你@example.com}"
SESSION="${SESSION:-24h}"
# ----------------

[ -z "$CF_API_TOKEN" ] && { echo "缺 CF_API_TOKEN"; exit 1; }
[ -z "$CF_ACCOUNT_ID" ] && { echo "缺 CF_ACCOUNT_ID"; exit 1; }

API="https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID"

# 1) 创建 Access 应用
echo "==> 创建 Access 应用: $APP_DOMAIN"
APP_JSON=$(curl -s -X POST "$API/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$APP_NAME\",\"domain\":\"$APP_DOMAIN\",\"type\":\"self_hosted\",\"session_duration\":\"$SESSION\"}")
APP_ID=$(echo "$APP_JSON" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "   应用 id=$APP_ID"
[ -z "$APP_ID" ] && { echo "   创建应用失败,返回: $APP_JSON"; exit 1; }

# 2) 创建 Access 策略(仅我的邮箱)
echo "==> 创建策略: 仅 $EMAIL 可访问"
curl -s -X POST "$API/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"only-me\",\"decision\":\"allow\",\"include\":[{\"email\":{\"email\":\"$EMAIL\"}}]}"
echo ""
echo "==> 完成。访问 $APP_DOMAIN 会先要求邮箱验证。"
