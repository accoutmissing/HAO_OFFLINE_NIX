{ pkgs, ... }:
{
  # Clash Verge Rev（mihomo GUI 客户端）
  # mihomo（原 clash-meta）为核心，clash-verge-rev 为图形界面
  environment.systemPackages = with pkgs; [
    mihomo # 代理核心
    clash-verge-rev # GUI 客户端
  ];

  # 当前只安装客户端和核心，没有启用系统服务或 TUN 权限。
  # 普通代理可由用户启动；TUN 需另行配置 programs.clash-verge.serviceMode
  # 及服务访问组。不要通过 sudo 启动整个图形客户端来安装服务。
}
