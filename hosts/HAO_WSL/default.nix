# ── Windows WSL 测试配置 ─────────────────────────────────────
# 用途：在 Windows 的 WSL2 里跑 NixOS，验证 flake 配置。
# 相比 Hyper-V：安装即用、文件互通、终端可直接复制粘贴。
#
# Windows 侧准备（PowerShell 管理员）：
#   wsl --install NixOS
# 首次进入后先初始化：
#   sudo nixos-generate-config --no-filesystem  # 不需要，模块已内置
# 直接用本 flake 构建：
#   sudo nixos-rebuild switch --flake github:accoutmissing/HAO_OFFLINE_NIX#HAO_WSL

{ pkgs, ... }:

{
  # ── WSL 核心（nixos-wsl 模块） ────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = "feng";
    startMenuLaunchers = true;

    # 允许在 WSL 里直接调用 Windows 程序（explorer.exe 等）
    interop.register = true;
  };

  # ── 主机身份 ────────────────────────────────────────────────
  networking.hostName = "HAO_WSL";

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  # ── 用户（与 vars 保持一致） ────────────────────────────────
  users.users.feng = {
    isNormalUser = true;
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

  # 这是 Agent 调试环境；feng 没有声明登录密码，因此保留 passwordless sudo，
  # 避免首次切换配置后无法继续管理系统。
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "25.05";
}
