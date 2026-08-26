_:
let
  # CI 可通过环境变量提供不可登录的占位哈希；真实安装将 yescrypt 哈希写入
  # 仓库外的 secrets 文件（initialHashedPassword 字段）。
  # builtins.getEnv 只用于 CI assertion，不应承载真实密钥。
  ciPasswordHash = builtins.getEnv "CI_PASSWORD_HASH";

  # ── 二进制缓存（flake.nix nixConfig 与 base/nix.nix 共用） ──────
  # 注意：清华/中科大的 nix-channels/store 只缓存 channel tarball，
  # 对 nixpkgs 构建产物几乎无命中（真正的构建缓存是 cache.nixos.org）；
  # 保留仅供 channel 场景，不要指望它给普通构建加速。
  cachixSubstituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://noctalia.cachix.org"
  ];

  cachixTrustedPublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:4BzitgziQkMCO+4QhMhVA8Wp9T5IhzsaCqPCU3c1gQ8="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  # Git flake 不会携带被 .gitignore 排除的文件，因此 secrets 必须通过
  # HAO_SECRETS_FILE 指向仓库外的本地文件，并使用 `--impure` 求值。
  # 未设置时保留相对路径，方便非 Git 目录和本地调试使用。
  secretsPath = builtins.getEnv "HAO_SECRETS_FILE";
  secretsFile =
    if secretsPath != "" then builtins.toPath secretsPath else ./secrets.nix;
  secrets = if builtins.pathExists secretsFile then import secretsFile else { };
in
{
  username = "feng";
  userfullname = "Feng";
  useremail = "feng@example.com";

  # 主机名占位值（各 hosts/<hostname>/default.nix 中覆盖）
  hostname = null;

  # 初始密码（安装后首次登录用，需立即修改）
  # 生成: mkpasswd -m yescrypt
  # 哈希放在仓库外的 secrets.nix（勿提交到公开仓库，避免离线爆破）；
  # CI 可通过 CI_PASSWORD_HASH + --impure 注入不可登录的占位值；
  # 正常安装需设置 HAO_SECRETS_FILE 并使用 --impure，null assertion 会强制用户填写真实哈希。
  initialHashedPassword =
    if ciPasswordHash != "" then ciPasswordHash
    else secrets.initialHashedPassword or null; # null = 安装前必须设置

  # SSH 公钥（用于远程部署和管理）
  mainSshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHJG2tED+PbY4FNF1Og36ITsOiiRiQ1Zjta5xk8n6w6z"
  ];

  backupSshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO23SY/1mwLZK75D6WBGK2Em1/aVl4T9Puwgm1VlVKxz"
  ];

  # Hermes 云端接管专用公钥（与主人 main key 分离，可独立吊销）
  # ⚠️ 填入你的 Hermes 云端 SSH 公钥；留空则云端无法接入（fail-closed）
  hermesSshAuthorizedKeys = [
    # "ssh-ed25519 AAAA...hermes-cloud-key"
  ];

  # ── EasyTier 密钥（来自外部 secrets 文件，缺失时用空值降级） ──
  easytierNetworkSecret = secrets.easytierNetworkSecret or null; # deadnix: skip
  easytierPeers = secrets.easytierPeers or [ ]; # deadnix: skip

  # ── Nix 缓存（供 flake.nix nixConfig 与 base/nix.nix 引用） ──
  inherit cachixSubstituters cachixTrustedPublicKeys;
}
