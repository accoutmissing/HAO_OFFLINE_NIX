{ pkgs, myvars, ... }:
{
  home = {
    inherit (myvars) username;
    homeDirectory = "/home/${myvars.username}";
    stateVersion = "26.05";
  };

  # 用户级包
  home.packages = with pkgs; [
    # 开发
    pnpm_11 # pnpm（显式锁定版本，避免 nixpkgs 别名变化）
    yarn # Yarn classic v1

    # 工具
    bat # cat 替代（zsh alias cat=bat）
    ripgrep # 下面 shellAliases 里的 grep=rg 需要它；桌面主机由 base 模块提供，
    # 但精简主机（如 HAO_WSL）不导入 base 模块，放在这里才能自洽
    lazygit
    delta # git diff 高亮
    gh # GitHub CLI
  ];

  # Git 配置
  programs.git = {
    enable = true;
    settings = {
      user.name = myvars.userfullname;
      user.email = myvars.useremail;
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
