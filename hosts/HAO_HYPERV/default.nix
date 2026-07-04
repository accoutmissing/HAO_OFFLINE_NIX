# ── Hyper-V 虚拟机测试配置 ────────────────────────────────────
# 用途：在 Windows Hyper-V 中验证 NixOS 配置（不涉及 GPU/游戏）
#
# Hyper-V 创建 VM 时：
#   - 第 2 代（UEFI）
#   - 安全启动：关闭
#   - 内存：≥ 4GB
#   - 网络：Default Switch
#   - 磁盘：≥ 30GB VHDX

{ lib, pkgs, ... }:

{
  imports = [
    # VM 不需要 disko 分区，用 nixos-generate-config 生成 hardware-config
  ];

  # ── 主机身份 ──────────────────────────────────────────────────────
  networking.hostName = "HAO_HYPERV";

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
