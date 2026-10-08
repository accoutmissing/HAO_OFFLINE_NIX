# ── Windows VM 支持（KVM/QEMU + virt-manager / quickemu） ──────────
# 参考：
#   https://crescentro.se/posts/windows-vm-nixos/
#   https://wiki.nixos.org/wiki/QEMU
#
# 固件由当前系统闭包引用；tmpfiles 提供稳定入口，软链本身不是 GC root。
# VARS 是只读模板，每台 VM 必须使用独立的可写 NVRAM 文件。

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

  # firmware / variables 已是完整文件路径，不能再追加文件名。
  # libvirt 的 loader 指向 CODE，nvram template 指向 VARS；
  # 实际 nvram 由 libvirt 为每台 VM 单独创建，不直接写这些模板。
  # 使用微软密钥模板的 VM 还需要启用 Secure Boot 和 TPM 设备。
  systemd.tmpfiles.rules = [
    "L+ /var/lib/ovmf/OVMF_CODE.fd - - - - ${pkgs.OVMFFull.firmware}"
    "L+ /var/lib/ovmf/OVMF_VARS.fd - - - - ${pkgs.OVMFFull.variables}"
    "L+ /var/lib/ovmf/OVMF_VARS.ms.fd - - - - ${pkgs.OVMFFull.variablesMs}"
  ];

  # spice USB 重定向：virt-manager 里把宿主 USB 设备转给 Windows VM
  virtualisation.spiceUSBRedirection.enable = true;

  # quickemu：quickget windows 11 && quickemu --vm windows-11.conf 一行建 VM
  environment.systemPackages = with pkgs; [
    quickemu
    spice-gtk # SPICE 客户端工具
  ];
}
