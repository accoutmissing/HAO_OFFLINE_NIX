{ config, lib, modulesPath, ... }:
{
  # Portable baseline for the i7-8750H / GTX 1060 laptop. No UUIDs or secrets.
  # The installer and later github: rebuilds use this same tracked module.
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "usb_storage"
    "uas"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.extraModulePackages = [ ];

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
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
