#!/usr/bin/env bash
set -euo pipefail

# 首次配置：复制 secrets 模板，提示填入真实值

SECRETS_DIR="$(cd "$(dirname "$0")/../vars" && pwd)"
TEMPLATE="$SECRETS_DIR/secrets.example.nix"
TARGET="$SECRETS_DIR/secrets.nix"

if [ -f "$TARGET" ]; then
  echo "✓ secrets.nix 已存在，跳过"
else
  cp "$TEMPLATE" "$TARGET"
  echo "✓ 已创建 $TARGET"
fi

echo ""
echo "📝 接下来编辑 $TARGET："
echo "   1. 把 initialHashedPassword = null 换成 mkpasswd -m yescrypt 生成的哈希（必须！否则无法登录）"
echo "   2. 把 REPLACE_WITH_YOUR_SECRET 换成 EasyTier 密钥"
echo "   3. 把 <YOUR_VPS_IP> 换成 VPS 实际地址"
echo "   4. 如启用 hermes-access，把 Hermes 云端公钥填入 vars/default.nix 的 hermesSshAuthorizedKeys"
echo ""
echo "   vim vars/secrets.nix"
