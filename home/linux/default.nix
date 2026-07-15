{ lib, pkgs, myvars, ... }:
{
  home = {
    username = myvars.username;
    homeDirectory = "/home/${myvars.username}";
    stateVersion = "25.05";
  };

  # 用户级包
  home.packages = with pkgs; [
    # 开发
    pnpm                      # top-level 别名 (pnpm_11)
    nodePackages.yarn         # Yarn classic v1（pkgs.yarn 可能已移除，用 nodePackages 更可靠）

    # 工具
    bat                       # cat 替代（zsh alias cat=bat）
    lazygit
    delta                     # git diff 高亮
    gh                        # GitHub CLI
  ];

  # Git 配置
  programs.git = {
    enable = true;
    userName = myvars.userfullname;
    userEmail = myvars.useremail;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # Zsh 配置（纯 zsh，提示符由 starship 接管）
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      grep = "rg";
      cat = "bat";
    };
  };

  # Starship 提示符（替代 oh-my-zsh，轻量且不冲突）
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # 让 home-manager 不要管 NixOS 已经管的部分
  news.display = "silent";
}
