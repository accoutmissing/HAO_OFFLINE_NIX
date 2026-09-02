{ myvars, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix # 磁盘、内核模块（by-label，跟踪在 git）
    ./nvidia.nix # RTX 4070 Super 驱动
  ];

  # ── 主机身份 ────────────────────────────────────────────────────────
  networking.hostName = myvars.hostname; # 由 mkSystem 注入，与 flake.nix 单一来源

  # kvm_intel 已在 hardware-configuration.nix 中声明，此处不重复
  environment.systemPackages = with pkgs; [
    powertop
  ];

  # ── 构建优化（14核20线程 + 32GB 内存） ──────────────────────────────
  nix.settings = {
    max-jobs = "auto";
    cores = 0;
  };

  # ── 模块开关（与笔记本共用 desktop/base 模块） ────────────────────
  modules.desktop.hermes-access.enable = true;
  modules.desktop.ai-agent.enable = true;
  modules.desktop.first-run.enable = true;
  modules.desktop.noctalia.enable = true;
  modules.desktop.gaming.enable = true;
}
