{ myvars, ... }:
{
  # ── 许可：允许 unfree 包（NVIDIA 驱动 / Steam / Proton / Wine） ──
  nixpkgs.config.allowUnfree = true;

  # Nix 自身设置
  nix = {
    settings = {
      # 二进制缓存（与 flake.nix nixConfig 共用 myvars 定义）
      substituters = myvars.cachixSubstituters;
      trusted-public-keys = myvars.cachixTrustedPublicKeys;

      # 保持 Nix 默认的关闭状态；开启会用硬链接去重 store 文件，节省磁盘，
      # 但也增加文件扫描开销，可按本机磁盘空间和构建耗时决定。
      auto-optimise-store = false;

      experimental-features = [ "nix-command" "flakes" ];
      # admin 是有意授权的系统调试 Agent 账户；Nix trusted-users 等同 root 权限。
      trusted-users = [ "root" "@wheel" ];

      # 国内网络优化：超时缩短，避免因国际连接卡死
      download-attempts = 3;
      connect-timeout = 10;
    };

    # 自动 GC（每周清理 7 天前的旧版本）
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
