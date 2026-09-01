_:
let
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

in
{
  username = "feng";
  userfullname = "Feng";
  useremail = "feng@example.com";

  # 主机名占位值（各 hosts/<hostname>/default.nix 中覆盖）
  hostname = null;

  # 敏感内容只在系统激活/服务启动时读取，不能作为 Nix 值进入 world-readable store。
  # 安装前运行 scripts/setup.sh，再以 root 执行 scripts/install-secrets.sh。
  passwordHashFile = "/var/lib/hao-secrets/feng-password-hash";
  easytierEnvironmentFile = "/var/lib/hao-secrets/easytier.env";

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

  # ── Nix 缓存（供 flake.nix nixConfig 与 base/nix.nix 引用） ──
  inherit cachixSubstituters cachixTrustedPublicKeys;
}
