{ myvars, pkgs, ... }:
{
  # 禁止系统外修改用户
  users.mutableUsers = false;

  # 安全检查：防止 initialHashedPassword = null 导致锁死
  assertions = [
    {
      assertion = myvars.initialHashedPassword != null;
      message = ''
        ⛔ 安全阻止：initialHashedPassword 未设置（null），且 mutableUsers = false。

        这会在安装后导致无法登录，且无法用 passwd 修改密码。

        → 请用 mkpasswd -m yescrypt 生成哈希，
          填入 vars/secrets.nix 的 initialHashedPassword（参考 vars/secrets.example.nix）
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
      "systemd-journal"  # 只读访问全部系统日志（远程调试 journalctl 用）
    ];
    shell = pkgs.zsh;

    # 主人主密钥 + 备份密钥在 base 层挂载，保证未启用 hermes-access 的
    # 主机（如 HAO_HYPERV）也能 SSH 登录
    openssh.authorizedKeys.keys =
      myvars.mainSshAuthorizedKeys ++ myvars.backupSshAuthorizedKeys;
  };

  users.users.root = {
    # root 完全锁定：无密码、无 SSH 密钥，任何登录途径都不放行；
    # 维护统一走 feng + sudo（wheel 组）
    hashedPassword = "!";
  };
}
