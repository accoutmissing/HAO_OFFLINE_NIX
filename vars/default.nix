_:
let
  # ── 二进制缓存（base/nix.nix 使用；与 flake.nix 的 nixConfig 保持同步） ──────
  # 清华/中科大的 nix-channels/store 提供 Nixpkgs 二进制缓存，不仅是 channel tarball。
  # 中科大使用动态缓存；缓存命中和下载速度需按具体包及网络情况判断。
  # Nix 按缓存的 Priority 选择源（数值越小越优先），不只看列表顺序。
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
  username = "admin";
  userfullname = "Admin";
  useremail = "admin@example.com";

  # 主机名占位值（各 hosts/<hostname>/default.nix 中覆盖）
  hostname = null;

  # 敏感内容只在系统激活/服务启动时读取，不能作为 Nix 值进入 world-readable store。
  # 安装前运行 scripts/setup.sh，再以 root 执行 scripts/install-secrets.sh。
  passwordHashFile = "/var/lib/hao-secrets/admin-password-hash";
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

  # ── Nix 缓存（供 base/nix.nix 引用） ──
  inherit cachixSubstituters cachixTrustedPublicKeys;
}
