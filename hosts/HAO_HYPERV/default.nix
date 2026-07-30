# ── Hyper-V 虚拟机测试配置 ────────────────────────────────────
# 用途：在 Windows Hyper-V 中验证 NixOS 配置（不涉及 GPU/游戏）
#
# Hyper-V 创建 VM 时：
#   - 第 2 代（UEFI）
#   - 安全启动：关闭
#   - 内存：≥ 4GB
#   - 网络：Default Switch
#   - 磁盘：≥ 30GB VHDX

{ lib, myvars, ... }:

let
  hasHardwareConfig = builtins.pathExists ./hardware-configuration.nix;
in
{
  imports = lib.optionals hasHardwareConfig [ ./hardware-configuration.nix ];

  # ── 主机身份 ──────────────────────────────────────────────────────
  networking.hostName = myvars.hostname;   # 由 mkSystem 注入，与 flake.nix 单一来源

  # ── 兜底文件系统（仅在 hardware-configuration.nix 缺失时生效） ────
  # 与 README 的 Hyper-V 手动分区命令一致（mkfs.fat -n BOOT / mkfs.btrfs -L NIXOS，无子卷）；
  # 让 CI 能完整求值，真机上仍推荐生成硬件配置并 git add -f
  fileSystems = lib.mkIf (!hasHardwareConfig) {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "btrfs";
      options = [ "compress=zstd" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # ── Hyper-V 集成服务 ────────────────────────────────────────────
  virtualisation.hypervGuest.enable = true;

  # ── 引导（Hyper-V Gen 2 是 UEFI） ──────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;  # VM 里不需要

  # 黑名单 Hyper-V 合成帧缓冲（可能跟 Wayland 冲突）
  boot.blacklistedKernelModules = [ "hyperv_fb" ];

  # ── 关闭物理机专属服务 ──────────────────────────────────────────
  services.fwupd.enable = lib.mkForce false;
  services.fstrim.enable = lib.mkForce false;

  # ── 显示：软件渲染（VM 里没有 NVIDIA/Intel 直通） ───────────────
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];

  # ── 模块开关 ────────────────────────────────────────────────────
  modules.desktop.noctalia.enable = true;      # 桌面：开（验证桌面壳层）
  modules.desktop.gaming.enable = false;       # 游戏：关（无 GPU）
  modules.desktop.hermes-access.enable = false; # 远程：关（测试不需要）
}
