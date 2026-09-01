# ── Windows VM 支持（KVM/QEMU + virt-manager / quickemu） ──────────
# 参考：
#   https://crescentro.se/posts/windows-vm-nixos/
#   https://wiki.nixos.org/wiki/QEMU
#
# 坑位说明：nix-collect-garbage 会清掉 OVMF 固件的 store 路径，
# 导致已有 VM 起不来（UEFI firmware not found）。
# 这里用 tmpfiles 把固件固定链到 /var/lib/ovmf，VM 配置里统一指向该路径。

{ pkgs, ... }:

{
  # ── libvirtd/QEMU：Win11 需要 TPM(swtpm) + UEFI(OVMF) ───────────────
  virtualisation.libvirtd = {
    enable = true; # 已在 modules/desktop/virtualisation.nix 启用，此处补充 qemu 参数
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true; # Windows 11 强制要求 TPM 2.0
    };
  };

  # OVMF 固件持久化，避免 GC 后 VM 报 UEFI firmware not found
  # VM 里固件路径填 /var/lib/ovmf/OVMF_CODE.fd / OVMF_VARS.fd
  systemd.tmpfiles.rules = [
    "L+ /var/lib/ovmf/OVMF_CODE.fd - - - - ${pkgs.OVMFFull.firmware}/OVMF_CODE.fd"
    "L+ /var/lib/ovmf/OVMF_VARS.fd - - - - ${pkgs.OVMFFull.firmware}/OVMF_VARS.fd"
  ];

  # spice USB 重定向：virt-manager 里把宿主 USB 设备转给 Windows VM
  virtualisation.spiceUSBRedirection.enable = true;

  # quickemu：quickget windows 11 && quickemu --vm windows-11.conf 一行建 VM
  environment.systemPackages = with pkgs; [
    quickemu
    spice-gtk # SPICE 客户端工具
  ];
}
