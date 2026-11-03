{ pkgs, config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.gaming;
in
{
  options.modules.desktop = {
    gaming = {
      enable = mkEnableOption "游戏套件（Steam, Lutris, 游戏优化）";
      ntsync.enable = (mkEnableOption "Wine/Proton 的 NTSYNC 内核同步支持") // {
        default = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.14";
      };
    };
  };

  config = mkIf cfg.enable {
    # ── Steam（Proton 运行 AAA 游戏） ──────────────────────────────────
    programs.steam = {
      enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extest.enable = true;
      fontPackages = with pkgs; [
        wqy_zenhei # Steam 中文界面
      ];
    };

    # ── GameMode（系统级游戏性能优化） ─────────────────────────────────
    programs.gamemode.enable = true;

    # Wine 11 / GE-Proton 自动选择可用的 NTSYNC；保留开关便于按游戏对比。
    boot.kernelModules = lib.optionals cfg.ntsync.enable [ "ntsync" ];
    services.udev.extraRules = lib.mkIf cfg.ntsync.enable ''
      KERNEL=="ntsync", SUBSYSTEM=="misc", GROUP="users", MODE="0660"
    '';

    # nixpkgs 2026-11 起把 gtk2 标记为 broken（NixOS/nixpkgs#410814：最终版
    # 2.24.33 停在 2020-12，计划 27.05 移除），而 lutris 的 fhsenv rootfs 仍然
    # 把 gtk+2.24.33 拖进闭包，于是整台桌面的 toplevel 直接拒绝求值：
    #   error: Refusing to evaluate package 'gtk+-2.24.33' ... because it has problems
    # 官方给的出口就是 problems.handlers。这里是有意的、有期限的放行：warn 会在
    # 构建日志里继续提示，等 lutris 迁到 gtk3 就该删掉这条。
    nixpkgs.config.problems.handlers."gtk+".broken = "warn";

    # ── 系统级游戏包 ────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      lutris
      heroic # Epic/GOG/亚马逊游戏客户端
      protonup-qt # Proton 版本管理（GUI）
      vkbasalt # Vulkan 后处理（锐化/增强）
      mangohud
      wineWow64Packages.stable # 日用 Wine，支持 32/64 位 Windows 程序
      winetricks
      protonplus
      umu-launcher
      moonlight-qt
    ];
  };
}
