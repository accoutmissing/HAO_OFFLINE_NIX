{ config, lib, myvars, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.hermes-access;
in
{
  options.modules.desktop.hermes-access = {
    enable = mkEnableOption "云端 Hermes 远程接管";
  };

  config = mkIf cfg.enable {
    # ── 云端 SSH 公钥（追加到 base/ssh.nix 之上） ────────────────────
    users.users.${myvars.username}.openssh.authorizedKeys.keys =
      myvars.mainSshAuthorizedKeys;

    # ── 免密 sudo（远程管理用） ─────────────────────────────────────────
    security.sudo.extraRules = [
      {
        users = [ myvars.username ];
        commands = [
          { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    # ── EasyTier 组网 ───────────────────────────────────────────────────
    # 与 VPS Hermes 建立 P2P 虚拟网络（IP 自动分配）
    # 密钥和 peer 列表来自 vars/secrets.nix（gitignored），
    # 公开仓库用户复制 vars/secrets.example.nix → vars/secrets.nix 填入实际值
    services.easytier = {
      enable = true;

      instances.hao_link = {
        settings = {
          network_name = "hao_link";
          network_secret = myvars.easytierNetworkSecret or null; # deadnix: skip
          dhcp = true;
          hostname = myvars.hostname;

          listeners = [
            "tcp://0.0.0.0:11010"
            "udp://0.0.0.0:11010"
          ];

          peers = myvars.easytierPeers or [ ]; # deadnix: skip
        };
      };
    };

    # ── 防火墙 ──────────────────────────────────────────────────────────
    networking.firewall = {
      allowedTCPPorts = [ 11010 ];
      allowedUDPPorts = [ 11010 ];
    };
  };
}
