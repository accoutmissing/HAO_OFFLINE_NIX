# ── NVIDIA Optimus 配置（GTX 1060 6GB） ───────────────────────────
# 方案：PRIME Offload — 默认用 Intel 核显省电，游戏/渲染时按需调用独显
# 用法：prime-run <程序>  或  nvidia-offload <程序>

{ pkgs, ... }:

{
  # ── 系统包 ──────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    nvtopPackages.full   # GPU 监控（Intel + NVIDIA；nvtop 顶层别名已移除）
    # prime-run / nvidia-offload 由 hardware.nvidia.prime.offload 内置提供
    # nvidia-prime 独立包已在 nixos-unstable 中移除
  ];

  # ── NVIDIA 驱动 ─────────────────────────────────────────────────────
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    # Pascal 架构不支持 fine-grained PM 和 Dynamic Boost
    powerManagement.finegrained = false;
    open = false;                       # GTX 1060 Pascal 不支持 nvidia-open
    nvidiaSettings = true;              # 提供 nvidia-settings GUI

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;        # 提供 nvidia-offload 命令
      };

      # ⚠️ Bus ID 装好系统后用 lspci 确认：
      #   lspci | grep -E "VGA|3D|Display"
      # Intel → 00:02.0 → PCI:0:2:0
      # NVIDIA → 01:00.0 → PCI:1:0:0
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ── 图形栈（24.11 起 hardware.opengl 更名为 hardware.graphics） ────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;                 # Steam 需要 32 位 GL
  };

  # 驱动列表（nvidia 驱动同时处理 NVIDIA 和 Intel）
  services.xserver.videoDrivers = [ "nvidia" ];
}
