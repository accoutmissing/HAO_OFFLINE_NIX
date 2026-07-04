{ pkgs, ... }:
{
  # Clash Verge Rev（mihomo GUI 客户端）
  # mihomo（原 clash-meta）为核心，clash-verge-rev 为图形界面
  environment.systemPackages = with pkgs; [
    mihomo                  # 代理核心
    clash-verge-rev         # GUI 客户端
  ];

  # 允许 mihomo 使用 tun 模式
  # 注意：这需要 sudo 或 setcap 权限
  # 使用 clash-verge-rev 的 tun mode 设置即可
}
