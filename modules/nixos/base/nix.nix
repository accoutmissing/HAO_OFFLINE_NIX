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

      # 关闭 auto-optimise：2.20 及更早的实现（in-place hardlink 修改）
      # 会让每次 rebuild 明显变慢；2.21+ 已重写实现，官方推荐开启，
      # 但个人实测仍保持关闭，如想试可改回 true 观察 rebuild 耗时。
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
