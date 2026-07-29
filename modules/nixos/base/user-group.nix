{ myvars, config, pkgs, lib, ... }:
{
  # 禁止系统外修改用户
  users.mutableUsers = false;

  # 安全检查：防止 initialHashedPassword = null 导致锁死
  assertions = [
    {
      assertion = myvars.initialHashedPassword != null;
      message = ''
        ⛔ 安全阻止：vars/default.nix 中 initialHashedPassword = null，且 mutableUsers = false。

        这会在安装后导致无法登录，且无法用 passwd 修改密码。

        → 请用 mkpasswd -m yescrypt 生成哈希，填入 vars/default.nix
      '';
    }
  ];

  users.users.${myvars.username} = {
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "podman"
      "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  users.users.root = {
    inherit (myvars) initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys;
  };
}
