{ pkgs, config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.gaming;
in
{
  options.modules.desktop = {
    gaming = {
      enable = mkEnableOption "游戏套件（Steam, Lutris, 游戏优化）";
    };
  };

  config = mkIf cfg.enable {
    # ── Steam（Proton 运行 AAA 游戏） ──────────────────────────────────
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extest.enable = true;
      fontPackages = with pkgs; [
        wqy_zenhei  # Steam 中文界面
      ];
    };

    # ── GameMode（系统级游戏性能优化） ─────────────────────────────────
    programs.gamemode.enable = true;

    # ── 系统级游戏包 ────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      lutris
      heroic                    # Epic/GOG/亚马逊游戏客户端
      protonup-qt               # Proton 版本管理（GUI）
      vkbasalt                  # Vulkan 后处理（锐化/增强）
      mangohud
      gamescope
      winetricks
      protonplus
      umu-launcher
      moonlight-qt
    ];
  };
}
