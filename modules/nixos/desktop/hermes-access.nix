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
          # 必须用 /run/current-system/sw/bin 路径——sudoers 按字面路径匹配、
          # 不解析 symlink，写 /nix/store/... 会匹配不上 PATH 里的命令。
          # systemctl 不可无限制 NOPASSWD（`systemctl edit` 可逃逸拿 root shell），
          # 只放行远程管理必要的动词。
          { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl restart *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl status *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl daemon-reload"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    # ── EasyTier 组网 ───────────────────────────────────────────────────
    # 与 VPS Hermes 建立 P2P 虚拟网络（IP 自动分配）
    # 密钥和 peer 列表来自 vars/secrets.nix（gitignored），
    # 公开仓库用户复制 vars/secrets.example.nix → vars/secrets.nix 填入实际值
    # EasyTier 缺少密钥时不启用服务，也不创建实例（避免向非空字符串选项传 null）
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

    # ── 防火墙 ──────────────────────────────────────────────────────────
    networking.firewall = lib.mkIf (myvars.easytierNetworkSecret != null) {
      # 仅在 EasyTier 实际启用时放行端口，避免无条件暴露 11010
      allowedTCPPorts = [ 11010 ];
      allowedUDPPorts = [ 11010 ];
    };
  };
}
