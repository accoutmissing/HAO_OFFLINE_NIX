{ lib, ... }:
{
  # 状态兼容版本：保留首次安装时的数据格式/默认值，不用于锁定软件版本。
  # 软件版本由 flake.lock 固定；升级 nixpkgs 时不要随意修改 stateVersion。
  system.stateVersion = lib.mkDefault "26.05";

  # ── systemd-boot 配置（用 mkDefault 允许 host 层覆盖，如切换 GRUB） ──
  boot.loader.systemd-boot = {
    enable = lib.mkDefault true;
    configurationLimit = lib.mkDefault 10;
    consoleMode = lib.mkDefault "keep"; # 0/keep 最兼容，避免 4K 屏无信号
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true; # VM 测试时 override 为 false
  boot.loader.timeout = lib.mkDefault 8;

  # ── tmpfs on /tmp（减少 NVMe 写入） ──────────────────────────────
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";
}
