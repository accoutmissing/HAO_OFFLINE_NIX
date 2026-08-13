_:
{
  # 容器
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true; # 兼容 docker 命令
      defaultNetwork.settings.dns_enabled = true;
    };

    # 虚拟机
    libvirtd.enable = true;
  };

  # ARM 容器/交叉编译支持（podman / docker）
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
