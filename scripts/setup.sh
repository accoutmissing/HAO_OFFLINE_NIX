#!/usr/bin/env bash
set -euo pipefail

# 首次配置：创建不会被 Git 跟踪的本地 secrets 暂存目录。

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
EXAMPLE_DIR="$REPO_ROOT/secrets.example"
PASSWORD_FILE="$SECRETS_DIR/admin-password-hash"
EASYTIER_FILE="$SECRETS_DIR/easytier.env"
PENPOT_FILE="$SECRETS_DIR/penpot.env"
PENPOT_POSTGRES_FILE="$SECRETS_DIR/penpot-postgres.env"
SETUP_PENPOT=0
ROTATE_PENPOT=0

if [ "${1:-}" = "--penpot" ]; then
  SETUP_PENPOT=1
  shift
fi
if [ "${1:-}" = "--rotate" ] && [ "$SETUP_PENPOT" -eq 1 ]; then
  ROTATE_PENPOT=1
  shift
fi
if [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--penpot [--rotate]]" >&2
  exit 2
fi

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

if [ "$SETUP_PENPOT" -eq 1 ]; then
  if [ ! -e "$PENPOT_FILE" ] || [ ! -e "$PENPOT_POSTGRES_FILE" ] || [ "$ROTATE_PENPOT" -eq 1 ]; then
    for tool in base64 dd tr; do
      if ! command -v "$tool" >/dev/null 2>&1; then
        echo "错误：缺少生成 Penpot 密钥所需的命令 $tool。" >&2
        exit 1
      fi
    done
    umask 077
    penpot_key="$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | base64 | tr -d '\n')"
    db_password="$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr '+/' '-_' | tr -d '=\n')"
    if [ "${#penpot_key}" -ne 88 ] || [ "${#db_password}" -ne 43 ]; then
      echo "错误：无法生成符合预期长度的 Penpot 密钥。" >&2
      exit 1
    fi
    penpot_tmp="$(mktemp "$SECRETS_DIR/.penpot.env.XXXXXX")"
    postgres_tmp="$(mktemp "$SECRETS_DIR/.penpot-postgres.env.XXXXXX")"
    trap 'rm -f "$penpot_tmp" "$postgres_tmp"' EXIT
    {
      printf 'PENPOT_SECRET_KEY=%s\n' "$penpot_key"
      printf 'PENPOT_DATABASE_PASSWORD=%s\n' "$db_password"
    } >"$penpot_tmp"
    printf 'POSTGRES_PASSWORD=%s\n' "$db_password" >"$postgres_tmp"
    chmod 600 "$penpot_tmp"
    chmod 600 "$postgres_tmp"
    mv "$penpot_tmp" "$PENPOT_FILE"
    mv "$postgres_tmp" "$PENPOT_POSTGRES_FILE"
    trap - EXIT
    echo "✓ 已生成 Penpot 运行时密钥 $PENPOT_FILE（权限 600）；未输出密钥内容。"
  else
    chmod 600 "$PENPOT_FILE"
    echo "· 已保留现有 Penpot 密钥 $PENPOT_FILE；没有重新生成。"
  fi
fi

echo ""
echo "📝 接下来："
echo "   1. 执行 mkpasswd -m yescrypt > \"$PASSWORD_FILE\"（必须，否则无法登录）"
echo "   2. 如需 EasyTier，编辑 $EASYTIER_FILE；不用时保留 CHANGE_ME"
echo "   3. 如启用 hermes-access，把 Hermes 云端公钥填入 vars/default.nix 的 hermesSshAuthorizedKeys"
echo "   4. 当前系统安装：sudo bash scripts/install-secrets.sh"
echo "      NixOS 安装盘目标：sudo bash scripts/install-secrets.sh /mnt"
echo ""
echo "   密钥安装后位于 /var/lib/hao-secrets，仅 root 可读。"
echo "   HAO_WSL 首次部署 Penpot：bash scripts/setup.sh --penpot 后再运行安装脚本。"
