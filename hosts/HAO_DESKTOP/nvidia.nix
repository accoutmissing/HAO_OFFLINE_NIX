# ── NVIDIA RTX 4070 Super 配置 ─────────────────────────────────
# 台式机直出模式（无 Optimus），显示器直接插显卡
# 默认独显全时工作，不需要 prime-offload 省电模式

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia # GPU 监控（nvtop 顶层别名已移除，需用 nvtopPackages.*）
    # nvidia-prime 包已在 nixos-unstable 中移除，prime-run 由
    # hardware.nvidia.prime.offload.enableOffloadCmd 内置提供
  ];

  # ── NVIDIA 驱动 ─────────────────────────────────────────────────────
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # RTX 4070 Super 是 Ada Lovelace 架构，支持 open kernel module
    # 若遇到稳定性问题，改为 open = false 切回 proprietary
    open = true;

    nvidiaSettings = true; # nvidia-settings GUI
  };

  # ── 图形栈（24.11 起 hardware.opengl 更名为 hardware.graphics） ────
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam 需要 32 位 GL
  };

  # 驱动列表
  services.xserver.videoDrivers = [ "nvidia" ];
}
