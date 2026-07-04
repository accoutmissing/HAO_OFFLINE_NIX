{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix   # 磁盘、内核模块（by-label，跟踪在 git）
    ./nvidia.nix                    # RTX 4070 Super 驱动
  ];

  # ── 主机身份 ────────────────────────────────────────────────────────
  networking.hostName = "HAO_DESKTOP";

  # ── Intel Raptor Lake（i5-13600KF） ────────────────────────────────
  boot.kernelModules = [ "kvm_intel" ];

  environment.systemPackages = with pkgs; [
    powertop
  ];

  # ── 模块开关（与笔记本共用 desktop/base 模块） ────────────────────
  modules.desktop.hermes-access.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
