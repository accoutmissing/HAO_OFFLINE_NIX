# ── 磁盘分区配置（disko） ─────────────────────────────────────────
# 单 NVMe 盘 UEFI + Btrfs 方案
# 安装时执行：
#   sudo nix --extra-experimental-features 'nix-command flakes' run \
#     /path/to/nixos#disko -- --mode disko hosts/HAO_DESKTOP/disko-config.nix
#
# 设备路径按实际调整（nvme0n1 / sda / nvme1n1 等）

{
  disk.main = {
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
