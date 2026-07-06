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

    # ── PipeWire 低延迟 ────────────────────────────────────────────────
    services.pipewire.lowLatency.enable = true;

    # ── GameMode（系统级游戏性能优化） ─────────────────────────────────
    programs.gamemode.enable = true;

    # ── 系统级游戏包 ────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      mangohud
      gamescope
      winetricks
      protonplus
      umu-launcher
      moonlight-qt
    ];
  };
}
