{ pkgs, ... }:
{
  # 系统级安装的软件包（桌面环境）
  environment.systemPackages = with pkgs; [
    # ── 设计工具 ─────────────────────────────────────────────────
    gimp
    inkscape
    krita
    blender
    font-manager
    # colord 在 NixOS 中用硬件模块启用

    # ── 开发工具 ─────────────────────────────────────────────────
    nodejs                    # 默认最新 LTS（当前约 Node 24）
    python3
    podman
    podman-compose

    # ── 终端工具 ─────────────────────────────────────────────────
    kitty                     # 终端模拟器

    # ── 图形工具 ─────────────────────────────────────────────────
    imv                       # 图片查看器
    mpv                       # 视频播放器
    pavucontrol               # 音量控制

    # ── 文件管理 ─────────────────────────────────────────────────
    thunar                    # 文件管理器
    thunar-archive-plugin
    thunar-volman
    gvfs                      # 挂载/回收站
    tumbler                   # 缩略图

    # ── 虚拟化管理 ────────────────────────────────────────────────
    virt-manager              # libvirtd GUI 管理
  ];
}
