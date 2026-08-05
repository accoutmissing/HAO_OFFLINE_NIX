{ pkgs, ... }:
{
  # 系统级安装的软件包（桌面环境）
  environment.systemPackages = with pkgs; [
    # ── 社交/通讯 ────────────────────────────────────────────────
    qq                        # 腾讯 QQ Linux 版
    wechat                    # 微信 Linux 版

    # ── 设计工具 ─────────────────────────────────────────────────
    gimp
    inkscape
    krita
    blender
    font-manager
    # colord 在 NixOS 中用硬件模块启用

    # ── Windows 兼容层 ───────────────────────────────────────────
    winboat                   # 容器化 Windows VM（WinBoat，Beta）
    freerdp                   # WinBoat 依赖的远程桌面协议

    # ── 开发工具 ─────────────────────────────────────────────────
    nodejs                    # 默认最新 LTS
    python3
    podman-compose            # podman CLI 由 virtualisation.podman.enable 提供，不重复安装

    # ── 终端工具 ─────────────────────────────────────────────────
    kitty                     # 终端模拟器

    # ── 图形工具 ─────────────────────────────────────────────────
    imv                       # 图片查看器
    mpv                       # 视频播放器
    pavucontrol               # 音量控制

    # ── 文件管理 ─────────────────────────────────────────────────
    # Thunar 系列在 xfce.* 命名空间，顶层别名不可靠
    xfce.thunar               # 文件管理器
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    gvfs                      # 挂载/回收站
    xfce.tumbler              # 缩略图

    # ── 虚拟化管理 ────────────────────────────────────────────────
    virt-manager              # libvirtd GUI 管理
  ];
}
