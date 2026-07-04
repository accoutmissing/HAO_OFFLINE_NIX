# 磁盘分区配置（disko）
# 安装系统时配置，格式参考: https://github.com/nix-community/disko
#
# 示例（单磁盘 UEFI + LUKS + Btrfs）：
# {
#   disk.main = {
#     type = "disk";
#     device = "/dev/nvme0n1";
#     content = {
#       type = "gpt";
#       partitions = {
#         ESP = {
#           size = "512M";
#           type = "EF00";
#           content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
#         };
#         root = {
#           size = "100%";
#           content = { type = "btrfs"; mountpoint = "/"; };
#         };
#       };
#     };
#   };
# }
