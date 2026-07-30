# 磁盘分区配置（disko）
# 安装系统时配置，格式参考: https://github.com/nix-community/disko
#
# ⚠️ 安装前请确认你的磁盘设备路径（lsblk），按需修改 device 字段。
#    默认值 /dev/nvme0n1 适用于大多数 NVMe 笔记本。
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";  # ← 按需修改（nvme0n1 / sda / nvme1n1 等）
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-n" "BOOT" ];   # 设 label，与备用 by-label 挂载方案一致
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-L" "NIXOS" ];   # 磁盘 label = NIXOS（与 hardware-config by-label 一致）
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
