#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/secrets"
TARGET_ROOT="/"
PENPOT_REQUIRED=0
ROTATE_PENPOT_DB=0

if [ "${1:-}" = "--penpot" ]; then PENPOT_REQUIRED=1; shift; fi
if [ "${1:-}" = "--rotate-penpot-db" ]; then PENPOT_REQUIRED=1; ROTATE_PENPOT_DB=1; shift; fi
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [--penpot|--rotate-penpot-db] [target-root]" >&2
  exit 2
fi
[ "$#" -eq 1 ] && TARGET_ROOT="$1"

case "$TARGET_ROOT" in
/*) ;;
*)
  echo "错误：目标根目录必须是绝对路径（例如 / 或 /mnt）" >&2
  exit 2
  ;;
esac

PASSWORD_SOURCE="$SOURCE_DIR/admin-password-hash"
EASYTIER_SOURCE="$SOURCE_DIR/easytier.env"
PENPOT_SOURCE="$SOURCE_DIR/penpot.env"
PENPOT_POSTGRES_SOURCE="$SOURCE_DIR/penpot-postgres.env"
TARGET_DIR="${TARGET_ROOT%/}/var/lib/hao-secrets"

if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请用 sudo 运行此脚本，以便创建 root-only 密钥目录。" >&2
  exit 1
fi

if [ "$ROTATE_PENPOT_DB" -ne 1 ]; then
  if [ ! -s "$PASSWORD_SOURCE" ]; then
    echo "错误：$PASSWORD_SOURCE 为空；请先运行 mkpasswd -m yescrypt 写入哈希。" >&2
    exit 1
  fi

  password_hash="$(tr -d '\r\n' <"$PASSWORD_SOURCE")"
  case "$password_hash" in
  \$y\$*) ;;
  *)
    # $y$ 是 yescrypt 哈希的字面前缀，不是变量。
    # shellcheck disable=SC2016
    echo '错误：密码哈希必须是 mkpasswd -m yescrypt 生成的单行 $y$... 值。' >&2
    exit 1
    ;;
  esac

  install -d -m 0700 -o root -g root "$TARGET_DIR"
  install -m 0600 -o root -g root "$PASSWORD_SOURCE" "$TARGET_DIR/admin-password-hash"
  echo "✓ 已安装密码哈希到 $TARGET_DIR/admin-password-hash"

  if [ -s "$EASYTIER_SOURCE" ] &&
    grep -q '^ET_NETWORK_SECRET=' "$EASYTIER_SOURCE" &&
    ! grep -q '^ET_NETWORK_SECRET=CHANGE_ME$' "$EASYTIER_SOURCE"; then
    install -m 0600 -o root -g root "$EASYTIER_SOURCE" "$TARGET_DIR/easytier.env"
    echo "✓ 已安装 EasyTier 环境文件到 $TARGET_DIR/easytier.env"
  else
    rm -f "$TARGET_DIR/easytier.env"
    echo "· EasyTier 密钥未填写，保持 fail-closed（服务不会启动）"
  fi
fi

if [ ! -s "$PENPOT_SOURCE" ] || [ ! -s "$PENPOT_POSTGRES_SOURCE" ]; then
  if [ "$PENPOT_REQUIRED" -eq 1 ]; then
    echo "Error: Penpot secret files are missing or empty. Run bash scripts/setup.sh --penpot first." >&2
    exit 1
  fi
  exit 0
fi

if ! awk '
  function value() { return substr($0, index($0, "=") + 1) }
  NR == 1 {
    if (index($0, "PENPOT_SECRET_KEY=") != 1) bad = 1
    secret = value()
    if (length(secret) != 88 || secret !~ /^[A-Za-z0-9+\/]+==$/) bad = 1
    next
  }
  NR == 2 {
    if (index($0, "PENPOT_DATABASE_PASSWORD=") != 1) bad = 1
    app_password = value()
    if (length(app_password) != 43 || app_password !~ /^[A-Za-z0-9_-]+$/) bad = 1
    next
  }
  NR > 2 { bad = 1 }
  END { if (bad || NR != 2) exit 1 }
' "$PENPOT_SOURCE"; then
  echo "Error: $PENPOT_SOURCE must contain generated Penpot application values." >&2
  exit 1
fi
if ! awk 'index($0, "POSTGRES_PASSWORD=") != 1 { bad = 1 } { password = substr($0, index($0, "=") + 1) } END { if (bad || NR != 1 || length(password) != 43 || password !~ /^[A-Za-z0-9_-]+$/) exit 1 }' "$PENPOT_POSTGRES_SOURCE"; then
  echo "Error: $PENPOT_POSTGRES_SOURCE must contain one generated POSTGRES_PASSWORD." >&2
  exit 1
fi
app_password="$(awk -F= '$1 == "PENPOT_DATABASE_PASSWORD" { sub(/^[^=]*=/, ""); print; exit }' "$PENPOT_SOURCE")"
db_password="$(awk -F= '$1 == "POSTGRES_PASSWORD" { sub(/^[^=]*=/, ""); print; exit }' "$PENPOT_POSTGRES_SOURCE")"
if [ "$app_password" != "$db_password" ]; then
  echo "Error: Penpot application and PostgreSQL passwords must match." >&2
  exit 1
fi

PENPOT_TARGET="$TARGET_DIR/penpot.env"
PENPOT_POSTGRES_TARGET="$TARGET_DIR/penpot-postgres.env"
if { [ -e "$PENPOT_TARGET" ] || [ -L "$PENPOT_TARGET" ]; } && { [ -e "$PENPOT_POSTGRES_TARGET" ] || [ -L "$PENPOT_POSTGRES_TARGET" ]; }; then
  if [ -L "$PENPOT_TARGET" ] || [ -L "$PENPOT_POSTGRES_TARGET" ]; then
    echo "Error: an installed Penpot secret file is a symbolic link; refusing to modify it." >&2
    exit 1
  fi
  if cmp -s "$PENPOT_SOURCE" "$PENPOT_TARGET" && cmp -s "$PENPOT_POSTGRES_SOURCE" "$PENPOT_POSTGRES_TARGET"; then
    chown root:root "$PENPOT_TARGET" "$PENPOT_POSTGRES_TARGET"
    chmod 0600 "$PENPOT_TARGET" "$PENPOT_POSTGRES_TARGET"
    echo "✓ Penpot secrets already match and are installed at $TARGET_DIR"
    exit 0
  fi
fi
if [ "$TARGET_ROOT" = / ] && command -v docker >/dev/null 2>&1 && docker volume inspect penpot_penpot_postgres_v15 >/dev/null 2>&1; then
  if [ "$ROTATE_PENPOT_DB" -ne 1 ]; then
    echo "Error: an existing Penpot PostgreSQL volume was found. Back it up, then run scripts/install-secrets.sh --rotate-penpot-db to update the database role and runtime file together." >&2
    exit 1
  fi
  if ! docker inspect -f '{{.State.Running}}' penpot-postgres 2>/dev/null | grep -qx true; then
    echo "Error: existing PostgreSQL volume found but penpot-postgres is not running; no credentials were changed." >&2
    exit 1
  fi
  install -d -m 0700 -o root -g root "$TARGET_DIR"
  staged_file="$(mktemp "$TARGET_DIR/.penpot.env.XXXXXX")"
  staged_postgres_file="$(mktemp "$TARGET_DIR/.penpot-postgres.env.XXXXXX")"
  trap 'rm -f "$staged_file" "$staged_postgres_file"' EXIT
  install -m 0600 -o root -g root "$PENPOT_SOURCE" "$staged_file"
  install -m 0600 -o root -g root "$PENPOT_POSTGRES_SOURCE" "$staged_postgres_file"

  # Stop app containers first. psql's \password reads both entries from stdin,
  # hashes client-side, and avoids cleartext in argv and PostgreSQL statement logs.
  systemctl stop docker-penpot-backend.service docker-penpot-exporter.service
  printf '%s\n%s\n' "$db_password" "$db_password" |
    docker exec -i --user postgres penpot-postgres psql -v ON_ERROR_STOP=1 -d penpot -c '\password penpot'
  mv -f "$staged_file" "$PENPOT_TARGET"
  mv -f "$staged_postgres_file" "$PENPOT_POSTGRES_TARGET"
  trap - EXIT
  echo "Updated the existing Penpot database role and installed root-only secrets. Run nixos-rebuild switch for HAO_WSL to restart the app with them."
  exit 0
fi

if [ "$ROTATE_PENPOT_DB" -eq 1 ]; then
  echo "Error: --rotate-penpot-db was requested but the existing Penpot PostgreSQL volume was not found." >&2
  exit 1
fi

if [ -e "$PENPOT_TARGET" ] || [ -L "$PENPOT_TARGET" ] || [ -e "$PENPOT_POSTGRES_TARGET" ] || [ -L "$PENPOT_POSTGRES_TARGET" ]; then
  echo "Error: installed Penpot secrets differ from source; refusing to overwrite them." >&2
  exit 1
fi
install -m 0600 -o root -g root "$PENPOT_SOURCE" "$PENPOT_TARGET"
install -m 0600 -o root -g root "$PENPOT_POSTGRES_SOURCE" "$PENPOT_POSTGRES_TARGET"
echo "✓ Installed Penpot secrets at $TARGET_DIR (root:root 0600)"
