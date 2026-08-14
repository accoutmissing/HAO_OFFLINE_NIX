{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.winboat;
in
{
  options.modules.desktop.winboat = {
    enable = mkEnableOption "WinBoat 容器化 Windows VM（Beta，仅物理机适用）";
  };

  config = mkIf cfg.enable {
    # WinBoat 0.9.0 目前依赖已 EOL 的 Electron 40.10.5；白名单随模块启用
    # 才生效（仅物理机开 WinBoat 的主机），上游发布不再依赖旧 Electron 的
    # 新版本后应立即移除本白名单。
    nixpkgs.config.permittedInsecurePackages = [ "electron-40.10.5" ];

    environment.systemPackages = with pkgs; [
      winboat # 容器化 Windows VM（WinBoat，Beta）
      freerdp # WinBoat 依赖的远程桌面协议
    ];
  };
}
