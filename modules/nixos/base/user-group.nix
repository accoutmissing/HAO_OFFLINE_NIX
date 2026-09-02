{ myvars, pkgs, ... }:
{
  # 禁止系统外修改用户
  users.mutableUsers = false;

  # 安全检查：密码哈希必须从 root-only 文件读取，不能进入 Nix store。
  assertions = [
    {
      assertion = myvars.passwordHashFile != "";
      message = ''
        ⛔ 安全阻止：passwordHashFile 未设置，且 mutableUsers = false。

        → 请运行 scripts/setup.sh 生成密码哈希，随后以 root 执行
          scripts/install-secrets.sh；安装环境使用目标根目录 /mnt。
      '';
    }
  ];

  users.users.${myvars.username} = {
    description = myvars.userfullname;
    hashedPasswordFile = myvars.passwordHashFile;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "podman"
      "libvirtd"
      "systemd-journal" # 只读访问全部系统日志（远程调试 journalctl 用）
    ];
    shell = pkgs.zsh;

    # 主人主密钥 + 备份密钥在 base 层挂载，保证未启用 hermes-access 的
    # 虚拟机主机（如 HAO_WSL）也能 SSH 登录
    openssh.authorizedKeys.keys =
      myvars.mainSshAuthorizedKeys ++ myvars.backupSshAuthorizedKeys;
  };

  users.users.root = {
    # root 完全锁定：无密码、无 SSH 密钥，任何登录途径都不放行；
    # 维护统一走 admin + sudo（wheel 组）
    hashedPassword = "!";
  };
}
