{ lib, myvars, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ./optimus.nix
      ./windows-vm.nix
    ]
    # 本地未跟踪覆盖（hosts/<host>/local.nix，被 .gitignore 忽略）。
    # 用于只对这台机器生效、但不希望进仓库的调整（例如损坏硬件的规避）。
    ++ lib.optional (builtins.pathExists ./local.nix) ./local.nix;

  # ── 主机身份 ────────────────────────────────────────────────────────
  networking.hostName = myvars.hostname;

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
      # 60% 开始充电，80% 停止；阈值需要电池驱动支持，用 tlp-stat -b 实机核对。
      START_CHARGE_THRESH_BAT0 = 60;
      STOP_CHARGE_THRESH_BAT0 = 80;
      # 插电和电池供电时均禁用 USB 自动挂起，避免外接设备/USB 重定向异常。
      USB_AUTOSUSPEND = 0;
      # TLP 默认在电池模式下会打开 WiFi 省电，会加剧 9462 的认证超时/固件
      # 崩溃；与 NetworkManager、iwlwifi 模块参数保持一致，两种供电都关闭。
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
    };
  };

  # 合盖行为由 logind 管理；LID_CLOSE_ACTION 不是 TLP 的配置参数。
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
  modules.desktop.first-run.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
