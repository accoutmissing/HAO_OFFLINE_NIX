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

# 密钥文件包含密码哈希和 EasyTier 网络密钥，不应被同机其他用户读取。
chmod 600 "$TARGET"

echo ""
echo "📝 接下来编辑 $TARGET："
echo "   1. 把 initialHashedPassword = null 换成 mkpasswd -m yescrypt 生成的哈希（必须！否则无法登录）"
echo "   2. 如需启用 EasyTier，再填入真实网络密钥和 peers；默认保持 null 以关闭服务"
echo "   3. 如启用 hermes-access，把 Hermes 云端公钥填入 vars/default.nix 的 hermesSshAuthorizedKeys"
echo "   4. 当前 shell 执行：export HAO_SECRETS_FILE=\"$TARGET\""
echo "   5. 后续 nixos 命令加 --impure，并用 sudo --preserve-env=HAO_SECRETS_FILE"
echo ""
echo "   vim vars/secrets.nix"
