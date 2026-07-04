{ myvars, config, pkgs, ... }:
{
  # 禁止系统外修改用户
  users.mutableUsers = false;

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
