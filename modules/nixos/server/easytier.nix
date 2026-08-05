# ── EasyTier 组网（服务器侧） ────────────────────────────────────
# 与桌面设备组成同一个虚拟局域网，供 SSH/自托管服务访问
{ config, lib, myvars, ... }:
{
  # 密钥存在 secrets.nix 才启用；否则完全关闭
  services.easytier = lib.mkIf (myvars.easytierNetworkSecret != null) {
    enable = true;

    instances.hao_link = {
      settings = {
        network_name = "hao_link";
        network_secret = myvars.easytierNetworkSecret;
        dhcp = true;
        hostname = myvars.hostname;

        listeners = [
          "tcp://0.0.0.0:11010"
          "udp://0.0.0.0:11010"
        ];

        peers = myvars.easytierPeers;
      };
    };
  };

  # EasyTier 端口（仅在启用时放行）
  networking.firewall.allowedTCPPorts = lib.mkIf (myvars.easytierNetworkSecret != null) [ 11010 ];
  networking.firewall.allowedUDPPorts = lib.mkIf (myvars.easytierNetworkSecret != null) [ 11010 ];
}
