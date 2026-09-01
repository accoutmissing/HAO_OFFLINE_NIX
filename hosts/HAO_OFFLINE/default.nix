{ lib, myvars, pkgs, ... }:
let
  inherit (myvars) hostname;

  # 硬件配置由 nixos-generate-config 在安装时生成
  # 不是每台机器都有，所以用 pathExists 按需导入
  hasHardwareConfig = builtins.pathExists ./hardware-configuration.nix;
in
{
  imports = lib.optionals hasHardwareConfig [ ./hardware-configuration.nix ]
    ++ [ ./optimus.nix ./windows-vm.nix ];

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
    powertop # 电源诊断
  ];

  services.thermald.enable = true; # Intel CPU 温度管理

  # ── TLP：常驻服务器化（电池保护 + 合盖不休眠） ────────────────
  services.tlp = {
    enable = true;
    settings = {
      # 长期插电防电池鼓包：60% 开始充电，80% 停止（部分神舟 BIOS 支持，不支持的机型自动忽略）
      START_CHARGE_THRESH_BAT0 = 60;
      STOP_CHARGE_THRESH_BAT0 = 80;
      # 合盖不采取任何操作（服务器不能睡）；外接显示器场景同样保持唤醒
      LID_CLOSE_ACTION = "none";
      # 交流电下禁用 USB 自动挂起，避免外接设备/USB 重定向异常
      USB_AUTOSUSPEND = 0;
    };
  };

  # 合盖不休眠由 logind 兜底（TLP 不接管 logind）
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # ── Noctalia 省电模式（笔记本） ─────────────────────────────────────
  home-manager.users.${myvars.username}.programs.noctalia-shell.settings.noctaliaPerformance = {
    disableWallpaper = lib.mkForce true;
    disableDesktopWidgets = lib.mkForce true;
  };

  # ── 模块开关 ─────────────────────────────────────────────────────────
  modules.desktop.hermes-access.enable = true;
  modules.desktop.ai-agent.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
