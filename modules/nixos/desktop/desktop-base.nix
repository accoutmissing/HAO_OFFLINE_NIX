{ lib, pkgs, myvars, ... }:
{
  # ── Display Manager（greetd 图形登录） ────────────────────────────
  services.greetd.enable = lib.mkDefault true;
  # ReGreet 作为 greeter（自动填充 greetd.settings.default_session；
  # 只开 greetd.enable 不配 greeter 会导致 settings 未定义，eval 报错）
  services.displayManager.regreet.enable = lib.mkDefault true;
  # greetd 崩溃后不自动重启，避免与 Niri session 重启逻辑冲突
  services.greetd.restart = false;

  # greeter 用户需要 video 组权限才能访问 GPU
  users.users.greeter = {
    isSystemUser = true;
    extraGroups = [ "video" ];
  };

  # ── 显示服务器 ──────────────────────────────────────────────────────
  programs.niri.enable = true; # Niri 窗口管理器
  # Niri 按需自动启动 Xwayland Satellite，供 Steam 等 X11 程序使用。
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # Wayland 必需
  programs.dconf.enable = true;
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome # niri 官方推荐 screencast 后端
      xdg-desktop-portal-gtk # 文件选择器
      xdg-desktop-portal-wlr # wlroots screencast 备选
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
    # 24.11 起 `enabled = "fcitx5"` 更名为 enable + type
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-rime
      qt6Packages.fcitx5-chinese-addons
      fcitx5-material-color
    ];
  };

  # 输入法组：键盘 + 拼音（Ctrl+Space 切换）。
  # 安装器默认只生成 keyboard-us，这里用 Home Manager 固化中文输入法。
  home-manager.users.${myvars.username}.xdg.configFile."fcitx5/profile" = {
    force = true;
    text = ''
      [Groups/0]
      # Group Name
      Name=Default
      # Layout
      Default Layout=us
      # Default Input Method
      DefaultIM=keyboard-us

      [Groups/0/Items/0]
      # Name
      Name=keyboard-us
      # Layout
      # Layout=

      [Groups/0/Items/1]
      # Name
      Name=pinyin
      # Layout
      # Layout=

      [GroupOrder]
      0=Default
    '';
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

  # ── 打印 ────────────────────────────────────────────────────────────
  services.printing.enable = true;

  # ── 电源管理 ────────────────────────────────────────────────────────
  powerManagement.enable = true;

  # ── 硬件维护 ────────────────────────────────────────────────────────
  services.fstrim.enable = true; # NVMe SSD 定期 TRIM
  services.fwupd.enable = true; # LVFS 固件更新（主板/SSD）

  # ── Flatpak ─────────────────────────────────────────────────────────
  services.flatpak.enable = true;
}
