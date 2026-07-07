{ lib, myvars, ... }:
{
  # ── 许可：允许 unfree 包（NVIDIA 驱动 / Steam / Proton / Wine） ──
  nixpkgs.config.allowUnfree = true;

  # Nix 自身设置
  nix = {
    settings = {
      # 二进制缓存（与 flake.nix nixConfig 共用 myvars 定义）
      substituters = myvars.cachixSubstituters;
      trusted-public-keys = myvars.cachixTrustedPublicKeys;

      # 关闭 auto-optimise：Nix 2.20+ 此选项会导致每次 rebuild 严重变慢
      auto-optimise-store = false;

      experimental-features = [ "nix-command" "flakes" ];
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
