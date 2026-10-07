# ── Windows WSL 测试配置 ─────────────────────────────────────
# 用途：在 Windows 的 WSL2 里跑 NixOS，验证 flake 配置。
#
# Windows 侧安装（NixOS 不在 `wsl --install` 的官方发行版列表里，必须用 tarball 导入）：
#   1) 下载 https://github.com/nix-community/NixOS-WSL/releases 的最新资产 nixos.wsl
#      （连同 nixos.wsl.sha256 一起校验；2026-10 实测版本 2605.7.2）
#   2) wsl --import HAO_WSL C:\Users\admin\wsl\HAO_WSL <nixos.wsl 路径> --version 2
#   3) wsl -d HAO_WSL
# 套用本 flake（镜像内没有 git 二进制，用 github: 形式即可）：
#   wsl -d HAO_WSL -u root -- \
#     nixos-rebuild switch --flake github:accoutmissing/HAO_OFFLINE_NIX#HAO_WSL
#
# ⚠️ 已知 WSL 缺陷与规避（2026-10-07 实测，WSL 2.7.10 / 内核 6.18.33.2）：
#   若另一个发行版（如 Ubuntu-26.04）同时以 uid 1000 的用户会话运行，本发行版的
#   systemd 用户会话会启动失败，journal 报
#   "user@1000.service: Failed to spawn executor: Device or resource busy"，
#   外部表现为 `wsl: Failed to start the systemd user session for 'admin'`，
#   `systemctl is-system-running` = degraded、`systemd-run --user` 不可用。
#   上游相关报告：nix-community/NixOS-WSL#888、microsoft/WSL#13188。
#   规避：把默认用户的 uid 固定为非 1000（见下方 uid = 1500），实测另一个发行版
#   同时运行时用户会话正常；不固定 uid 时也可用
#   `wsl -d <其它发行版> -u root` 或先 `wsl --terminate <其它发行版>` 规避。

{ pkgs, ... }:

{
  # ── WSL 核心（nixos-wsl 模块） ────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = "admin";
    startMenuLaunchers = true;

    # 允许在 WSL 里直接调用 Windows 程序（explorer.exe 等）
    interop.register = true;
  };

  # ── 主机身份 ────────────────────────────────────────────────
  networking.hostName = "HAO_WSL";

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  # ── 用户（与 vars 保持一致） ────────────────────────────────
  users.users.admin = {
    description = "Admin";
    isNormalUser = true;
    # WSL 缺陷规避：另一个发行版（如 Ubuntu-26.04）同时以 uid 1000 用户会话运行时，
    # 本发行版的 systemd 用户会话会启动失败（journal 报
    # "Failed to spawn executor: Device or resource busy"）。固定为非 1000 的 uid 避开该冲突。
    uid = 1500;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # ── 常用工具 ────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    htop
  ];

  # ── 二进制缓存镜像（与主配置一致，加速下载） ────────────────
  nix.settings.substituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:4BzitgziQkMCO+4QhMhVA8Wp9T5IhzsaCqPCU3c1gQ8="
  ];

  # 这是 Agent 调试环境；admin 没有声明登录密码，因此保留 passwordless sudo，
  # 避免首次切换配置后无法继续管理系统。
  security.sudo.wheelNeedsPassword = false;

  # 必须关掉可变用户：mutableUsers 默认为 true 时 NixOS 不会把声明中的新 uid 写进
  # /etc/passwd（激活日志只打印 “not applying UID change of user 'admin'
  # (1000 -> 1500)”），上面的 uid = 1500 便不生效，WSL 用户会话冲突依旧存在。
  users.mutableUsers = false;
  # mutableUsers = false 时 NixOS 会断言 “Neither the root account nor any wheel user
  # has a password or SSH authorized key”。本主机刻意不设登录密码（`wsl -d` 进入
  # 不校验密码），故显式声明允许无密码登录；这也是官方留给此类场景的开关。
  users.allowNoPasswordLogin = true;

  system.stateVersion = "25.05";
}
