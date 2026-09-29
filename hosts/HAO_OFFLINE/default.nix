{ lib, myvars, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ./optimus.nix ./windows-vm.nix ];

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
  modules.desktop.first-run.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
