{ config, lib, pkgs, myvars, ... }:
let
  inherit (lib) mkEnableOption mkIf removePrefix;
  cfg = config.modules.desktop.ai-agent;

  scriptBody = path: removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);

  # omp 使用官方预编译二进制（见 pkgs/omp/default.nix），避免本地编译整套 Rust/bun
  omp = pkgs.callPackage ../../../pkgs/omp { };

  haoAgent = pkgs.writeShellApplication {
    name = "hao-agent";
    runtimeInputs = [
      omp
      pkgs.codex
      pkgs.coreutils
      pkgs.fuzzel
      pkgs.opencode
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
      tmux
    ];
    text = scriptBody ../../../scripts/hao-agent-toggle.sh;
  };

  haoAgentStatus = pkgs.writeShellApplication {
    name = "hao-agent-status";
    runtimeInputs = with pkgs; [
      haoAgent
      jq
      niri
    ];
    text = scriptBody ../../../scripts/hao-agent-status;
  };
in
{
  options.modules.desktop.ai-agent.enable =
    mkEnableOption "原生 AI Agent 入口（Codex、OpenCode、OMP）";

  config = mkIf cfg.enable {
    environment.systemPackages = [
      haoAgent
      haoAgentToggle
      haoAgentStatus
      omp
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
