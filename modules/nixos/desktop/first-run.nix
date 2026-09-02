{ config
, lib
, myvars
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf removePrefix;
  cfg = config.modules.desktop.first-run;
  scriptBody = path: removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);

  haoWelcome = pkgs.writeShellApplication {
    name = "hao-welcome";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = scriptBody ../../../scripts/hao-welcome.sh;
  };
in
{
  options.modules.desktop.first-run.enable =
    mkEnableOption "HAO 首次登录欢迎通知与快捷入口提示";

  config = mkIf cfg.enable {
    environment.systemPackages = [ haoWelcome ];

    home-manager.users.${myvars.username}.systemd.user.services.hao-first-login = {
      Unit = {
        Description = "Show the HAO first-login welcome";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${haoWelcome}/bin/hao-welcome";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
