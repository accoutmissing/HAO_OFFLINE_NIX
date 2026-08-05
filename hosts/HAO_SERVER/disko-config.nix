# ── 磁盘分区配置（disko）— 服务器 ─────────────────────────────────
# 单盘 UEFI + Btrfs 方案，设备路径按实际调整（nvme0n1 / sda / vda 等）
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-n" "BOOT" ];   # ⚠️ 必须设 label：hardware-configuration 按 by-label/BOOT 挂载
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-L" "NIXOS" ];   # 磁盘 label = NIXOS
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}
