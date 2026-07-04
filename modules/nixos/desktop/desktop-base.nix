{ config, lib, pkgs, ... }:
{
  # ── Display Manager（greetd + ReGreet 图形登录） ───────────────
  # ReGreet: GTK4 + Rust 的 Wayland 原生图形登录界面
  # 自动处理 greeter 命令和 PAM，我们补上显式 enable + restart 微调
  services.greetd.enable = lib.mkDefault true;
  programs.regreet.enable = true;
  services.greetd.restart = false;

  # greeter 用户需要 video 组权限才能访问 GPU
  users.users.greeter = {
    isSystemUser = true;
    extraGroups = [ "video" ];
  };

  # ── 显示服务器 ──────────────────────────────────────────────────────
  programs.niri.enable = true;      # Niri 窗口管理器

  # Wayland 必需
  programs.dconf.enable = true;
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome  # niri 官方推荐 screencast 后端
      xdg-desktop-portal-gtk    # 文件选择器
      xdg-desktop-portal-wlr    # wlroots screencast 备选
    ];
  };

  # ── polkit agent（GUI 提权弹窗，virt-manager/flatpak 等需要） ──
  systemd.user.services.polkit-niri = {
    description = "polkit agent for Niri";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
  };

  # ── 输入法（Fcitx5 + Rime） ────────────────────────────────────────
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-rime
      fcitx5-chinese-addons
      fcitx5-material-color
    ];
  };

  # ── 音频（PipeWire） ────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # ── 蓝牙 ────────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── 打印 ────────────────────────────────────────────────────────────
  services.printing.enable = true;

  # ── 电源管理 ────────────────────────────────────────────────────────
  powerManagement.enable = true;

  # Linux 内核 CPU 频率调度（台式机 + 笔记本通用）
  services.power-profiles-daemon.enable = true;

  # ── 硬件维护 ────────────────────────────────────────────────────────
  services.fstrim.enable = true;    # NVMe SSD 定期 TRIM
  services.fwupd.enable = true;     # LVFS 固件更新（主板/SSD）

  # ── Flatpak ─────────────────────────────────────────────────────────
  services.flatpak.enable = true;
}
