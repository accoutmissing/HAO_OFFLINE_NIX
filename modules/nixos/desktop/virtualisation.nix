{ config, myvars, pkgs, ... }:
{
  # 容器
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true; # 兼容 docker 命令
      defaultNetwork.settings.dns_enabled = true;
    };

    # 虚拟机
    libvirtd = {
      enable = true;
      onShutdown = "shutdown";
      # 不恢复上次运行的 VM；显式设置 autostart 的 VM 仍会启动。
      onBoot = "ignore";
    };
  };

  programs.virt-manager.enable = true;
  # quickemu 直接访问 /dev/kvm；libvirtd 组已在 base 用户模块中声明。
  users.users.${myvars.username}.extraGroups = [ "kvm" ];

  # 只管理已经定义的 default 网络，不覆盖用户自定义网络或创建新网段。
  systemd.services.libvirt-default-network = {
    description = "Autostart the existing libvirt default network";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    partOf = [ "libvirtd.service" ];
    wantedBy = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ config.virtualisation.libvirtd.package pkgs.gnugrep ];
    script = ''
      set -eu
      networks=$(virsh --connect qemu:///system net-list --all --name)
      if ! grep -Fxq default <<< "$networks"; then
        exit 0
      fi

      virsh --connect qemu:///system net-autostart default
      inactive_networks=$(virsh --connect qemu:///system net-list --inactive --name)
      if grep -Fxq default <<< "$inactive_networks"; then
        virsh --connect qemu:///system net-start default
      fi
    '';
  };

  # ARM 容器/交叉编译支持（podman / docker）
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
