# ── 容器/虚拟化（服务器） ────────────────────────────────────────
# Podman 无根容器 + 自托管服务
{ pkgs, ... }:
{
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  environment.systemPackages = with pkgs; [
    podman-compose
    lazydocker         # 容器 TUI 管理
  ];
}
