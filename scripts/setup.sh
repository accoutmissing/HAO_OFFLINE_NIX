#!/usr/bin/env bash
set -euo pipefail

# 首次配置：创建不会被 Git 跟踪的本地 secrets 暂存目录。

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
EXAMPLE_DIR="$REPO_ROOT/secrets.example"
PASSWORD_FILE="$SECRETS_DIR/feng-password-hash"
EASYTIER_FILE="$SECRETS_DIR/easytier.env"

install -d -m 700 "$SECRETS_DIR"

if [ ! -e "$PASSWORD_FILE" ]; then
  : >"$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
  echo "✓ 已创建空密码哈希文件 $PASSWORD_FILE"
fi

if [ ! -e "$EASYTIER_FILE" ]; then
  cp "$EXAMPLE_DIR/easytier.env" "$EASYTIER_FILE"
  chmod 600 "$EASYTIER_FILE"
  echo "✓ 已创建 EasyTier 环境文件 $EASYTIER_FILE"
fi

chmod 600 "$PASSWORD_FILE" "$EASYTIER_FILE"

echo ""
echo "📝 接下来："
echo "   1. 执行 mkpasswd -m yescrypt > \"$PASSWORD_FILE\"（必须，否则无法登录）"
echo "   2. 如需 EasyTier，编辑 $EASYTIER_FILE；不用时保留 CHANGE_ME"
echo "   3. 如启用 hermes-access，把 Hermes 云端公钥填入 vars/default.nix 的 hermesSshAuthorizedKeys"
echo "   4. 当前系统安装：sudo bash scripts/install-secrets.sh"
echo "      NixOS 安装盘目标：sudo bash scripts/install-secrets.sh /mnt"
echo ""
echo "   密钥安装后位于 /var/lib/hao-secrets，仅 root 可读。"
