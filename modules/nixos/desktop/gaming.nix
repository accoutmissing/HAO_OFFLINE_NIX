{ pkgs, nix-gaming, config, lib, ... }:
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
    imports = [
      nix-gaming.nixosModules.pipewireLowLatency
      nix-gaming.nixosModules.platformOptimizations
    ];

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

    # ── PipeWire 低延迟 + 平台优化（nix-gaming） ─────────────────────
    services.pipewire.lowLatency.enable = true;
    programs.steam.platformOptimizations.enable = true;

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

    # ── Lutris（非 Steam 游戏） ─────────────────────────────────────────
    programs.lutris = {
      enable = true;
      defaultWinePackage = pkgs.proton-ge-bin;
      steamPackage = pkgs.steam;
      protonPackages = [ pkgs.proton-ge-bin ];
      winePackages = with pkgs; [ wineWow64Packages.full ];
      extraPackages = with pkgs; [
        winetricks
        gamescope
        gamemode
        mangohud
        umu-launcher
      ];
    };
  };
}
