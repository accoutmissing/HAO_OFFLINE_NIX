{ lib, myvars, pkgs, ... }:
let
  inherit (myvars) hostname;

  # 硬件配置由 nixos-generate-config 在安装时生成
  # 不是每台机器都有，所以用 pathExists 按需导入
  hasHardwareConfig = builtins.pathExists ./hardware-configuration.nix;
in
{
  imports = []
    ++ lib.optionals hasHardwareConfig [ ./hardware-configuration.nix ]
    ++ [ ./optimus.nix ];

  # ── 主机身份 ────────────────────────────────────────────────────────
  networking.hostName = hostname;

  # ── 兜底文件系统（仅在 hardware-configuration.nix 缺失时生效） ────
  # 与 disko-config.nix / README 手动分区布局一致（by-label）：
  # 1. 让 CI 的 nix flake check / eval 能完整求值（否则报根文件系统未定义）
  # 2. 真机上仍推荐生成硬件配置并 git add -f（含 initrd 驱动等信息）
  fileSystems = lib.mkIf (!hasHardwareConfig) {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" "noatime" ];
    };
    "/home" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # ── Intel CPU（Coffee Lake i7-8750H） ──────────────────────────────
  boot.kernelModules = [ "kvm_intel" ];

  environment.systemPackages = with pkgs; [
    powertop         # 电源诊断
  ];

  services.thermald.enable = true;      # Intel CPU 温度管理
  services.tlp.enable = true;           # 电池优化

  # zram 压缩内存交换（磁盘无 swap 分区，游戏/编译时防 OOM）
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # TLP 与 power-profiles-daemon 冲突（上游不推荐同时启用）
  # 笔记本保留 TLP（更细粒度的电池优化），关闭 desktop-base 中启用的 ppd
  services.power-profiles-daemon.enable = lib.mkForce false;

  # ── Noctalia 省电模式（笔记本） ─────────────────────────────────────
  home-manager.users.${myvars.username}.programs.noctalia-shell.settings.noctaliaPerformance = {
    disableWallpaper = lib.mkForce true;
    disableDesktopWidgets = lib.mkForce true;
  };

  # ── 模块开关 ─────────────────────────────────────────────────────────
  modules.desktop.hermes-access.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
