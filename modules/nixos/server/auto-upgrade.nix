# ── 自动更新（服务器长期运行，定期拉最新） ─────────────────────
{ lib, ... }:
{
  # 每周自动 nixos-rebuild switch 到最新 flake
  system.autoUpgrade = {
    enable = true;
    flake = "github:accoutmissing/HAO_OFFLINE_NIX#HAO_SERVER";
    dates = "weekly";
    allowReboot = true;     # 更新后自动重启（服务器可接受短暂中断）
    randomizedDelaySec = "15min";
  };

  # 旧版本自动清理（保留 3 代）
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
