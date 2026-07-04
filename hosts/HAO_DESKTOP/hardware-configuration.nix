# ── 硬件配置（HAO_DESKTOP） ──────────────────────────────────────
# 支持单系统 / 双系统（Windows + NixOS）两种场景
#
# 单系统：disko 自动分区 → by-label（NIXOS / BOOT）
# 双系统：手动分区 → EFI 分区可能来自 Windows（需用 UUID 或 partlabel）
#
# i5-13600KF（Raptor Lake）+ Z790 + RTX 4070 Super

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── 磁盘驱动 ──────────────────────────────────────────────────────────
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm_intel" ];
  boot.extraModulePackages = [ ];

  # ── 文件系统 ──────────────────────────────────────────────────────────
  # 单系统安装（by-label，与 disko-config.nix 一致）：
  #   /dev/disk/by-label/NIXOS  ← subvol=@ → /
  #                              ← subvol=@home → /home
  #   /dev/disk/by-label/BOOT   → /boot
  #
  # 双系统安装（Windows + NixOS）：
  #   EFI 分区由 Windows 创建，label 可能是 SYSTEM 而非 BOOT，
  #   需要改 /boot 的 device 为实际路径：
  #     lsblk -o NAME,LABEL,PARTLABEL,UUID,FSTYPE
  #     /dev/nvme0n1p1 → 对应改 device
  #
  # 安装完成后硬件配置固定为实际路径，日常 nixos-rebuild 不受影响。

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # ── 引导（双系统自动识别 Windows） ─────────────────────────────────
  # systemd-boot 会自动扫描 ESP 中的 Windows Boot Manager
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # ── CPU 微码 ──────────────────────────────────────────────────────────
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  # ── 平台 ──────────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
}
