# ── HAO_SERVER 服务器配置 ─────────────────────────────────────
# 用途：家庭服务器 / NAS / VPS 云服务器（公网）
# 特性：无桌面、SSH 加固、fail2ban、Podman 容器、EasyTier 组网、自动更新
#
# 部署前必做：
#   1. vars/default.nix 填入密码哈希（initialHashedPassword）
#   2. vars/secrets.nix 填入 EasyTier 密钥（可选，缺失则关闭组网）
#   3. 生成 hardware-configuration.nix 并 git add -f
#
# 部署命令（在服务器上）：
#   git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git -b HAO_SERVER /etc/nixos
#   cd /etc/nixos && sudo nixos-install --flake .#HAO_SERVER
#   （日常更新：sudo nixos-rebuild switch --flake .#HAO_SERVER）

{ lib, myvars, ... }:

let
  hasHardwareConfig = builtins.pathExists ./hardware-configuration.nix;
in
{
  imports =
    [ ]
    ++ lib.optionals hasHardwareConfig [ ./hardware-configuration.nix ]
    ++ [ ../../modules/nixos/server ];

  # ── 主机身份 ───────────────────────────────────────────────────
  networking.hostName = myvars.hostname;   # 由 mkSystem 注入
  networking.networkmanager.enable = lib.mkForce false;  # 服务器用 systemd-networkd 更稳

  # ── 兜底文件系统（无硬件配置时 CI 可求值） ────────────────────
  fileSystems = lib.mkIf (!hasHardwareConfig) {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" "noatime" ];
    };
  };

  # ── SSH（服务器核心入口） ─────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;    # 仅密钥登录
      PermitRootLogin = "no";            # 禁止 root 直接登录
      KbdInteractiveAuthentication = false;
    };
  };

  # ── 时区 / 语言 ───────────────────────────────────────────────
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── 系统包（轻量服务器工具） ─────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    btop
    ripgrep
    fd
    jq
    yq
    tmux
    mtr
  ];

  # ── 模块开关 ──────────────────────────────────────────────────
  # server 模块（hardening/easytier/containers/auto-upgrade/zram）
  # 已在 imports 中整体引入，默认全部启用
  # 若某台 VPS 不需要自动更新：system.autoUpgrade.enable = false

  system.stateVersion = "25.05";
}
