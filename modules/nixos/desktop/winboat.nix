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
    environment.systemPackages = with pkgs; [
      winboat # 容器化 Windows VM（WinBoat，Beta）
      freerdp # WinBoat 依赖的远程桌面协议
    ];
  };
}
