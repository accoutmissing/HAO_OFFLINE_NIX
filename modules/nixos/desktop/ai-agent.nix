{ config, lib, pkgs, myvars, ... }:
let
  inherit (lib) mkEnableOption mkIf removePrefix;
  cfg = config.modules.desktop.ai-agent;

  scriptBody = path: removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);

  haoAgent = pkgs.writeShellApplication {
    name = "hao-agent";
    runtimeInputs = with pkgs; [
      claude-code
      codex
      coreutils
      fuzzel
      opencode
    ];
    text = scriptBody ../../../scripts/hao-agent.sh;
  };

  haoAgentToggle = pkgs.writeShellApplication {
    name = "hao-agent-toggle";
    runtimeInputs = with pkgs; [
      haoAgent
      jq
      kitty
      niri
    ];
    text = scriptBody ../../../scripts/hao-agent-toggle.sh;
  };
in
{
  options.modules.desktop.ai-agent.enable =
    mkEnableOption "原生 AI Agent 入口（Codex、Claude Code、OpenCode）";

  config = mkIf cfg.enable {
    environment.systemPackages = [
      haoAgent
      haoAgentToggle
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
    ];

    home-manager.users.${myvars.username} = {
      programs.zsh.shellAliases = {
        ai = "hao-agent";
        ai-pick = "hao-agent --pick";
      };

      xdg.desktopEntries.hao-ai = {
        name = "HAO AI";
        genericName = "AI 编程助手";
        comment = "选择并启动本机 AI Agent";
        exec = "hao-agent-toggle";
        icon = "utilities-terminal";
        terminal = false;
        categories = [ "Development" ];
      };
    };
  };
}
