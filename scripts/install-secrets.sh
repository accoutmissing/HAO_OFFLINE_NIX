#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/secrets"
TARGET_ROOT="${1:-/}"

case "$TARGET_ROOT" in
  /*) ;;
  *)
    echo "错误：目标根目录必须是绝对路径（例如 / 或 /mnt）" >&2
    exit 2
    ;;
esac

PASSWORD_SOURCE="$SOURCE_DIR/feng-password-hash"
EASYTIER_SOURCE="$SOURCE_DIR/easytier.env"
TARGET_DIR="${TARGET_ROOT%/}/var/lib/hao-secrets"

if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请用 sudo 运行此脚本，以便创建 root-only 密钥目录。" >&2
  exit 1
fi

if [ ! -s "$PASSWORD_SOURCE" ]; then
  echo "错误：$PASSWORD_SOURCE 为空；请先运行 mkpasswd -m yescrypt 写入哈希。" >&2
  exit 1
fi

password_hash="$(tr -d '\r\n' < "$PASSWORD_SOURCE")"
case "$password_hash" in
  \$y\$*) ;;
  *)
    echo "错误：密码哈希必须是 mkpasswd -m yescrypt 生成的单行 \$y\$... 值。" >&2
    exit 1
    ;;
esac

install -d -m 0700 -o root -g root "$TARGET_DIR"
install -m 0600 -o root -g root "$PASSWORD_SOURCE" "$TARGET_DIR/feng-password-hash"
echo "✓ 已安装密码哈希到 $TARGET_DIR/feng-password-hash"

if [ -s "$EASYTIER_SOURCE" ] \
  && grep -q '^ET_NETWORK_SECRET=' "$EASYTIER_SOURCE" \
  && ! grep -q '^ET_NETWORK_SECRET=CHANGE_ME$' "$EASYTIER_SOURCE"; then
  install -m 0600 -o root -g root "$EASYTIER_SOURCE" "$TARGET_DIR/easytier.env"
  echo "✓ 已安装 EasyTier 环境文件到 $TARGET_DIR/easytier.env"
else
  rm -f "$TARGET_DIR/easytier.env"
  echo "· EasyTier 密钥未填写，保持 fail-closed（服务不会启动）"
fi
