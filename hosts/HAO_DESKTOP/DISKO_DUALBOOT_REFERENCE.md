# ── 磁盘分区参考 — 双系统（Windows + NixOS） ────────────────
#
# ⚠️ disko 不适合双系统场景（无法跳过已有分区号）。
# 请按以下步骤手动分区，再执行 nixos-install。
#
# 最终分区布局（2TB NVMe 示例）：
#   /dev/nvme0n1p1 — EFI (fat32, 512MB)  ← Windows 安装时创建
#   /dev/nvme0n1p2 — Windows (NTFS)       ← Windows 安装时创建
#   /dev/nvme0n1p3 — NixOS (Btrfs)        ← 手动创建
#
# 安装顺序：
#   1. 先装 Windows（Windows 安装时分区，留 ~500GB+ 未分配空间）
#   2. 再装 NixOS

# 本文件仅为参考，不直接用于 disko。
