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
    # ── 云端 SSH 公钥（独立于主人 main key，可单独吊销） ─────────────
    # 注意：下面 sudo 规则绑定到「用户 admin」而非具体密钥，任何能登录 admin
    # 的密钥都享有同样 NOPASSWD 权限；独立 key 的意义在身份区分与吊销，
    # 并非权限隔离。
    users.users.${myvars.username}.openssh.authorizedKeys.keys =
      myvars.hermesSshAuthorizedKeys;

    # ── 免密 sudo（远程管理用） ─────────────────────────────────────────
    security.sudo.extraRules = [
      {
        users = [ myvars.username ];
        commands = [
          # 必须用 /run/current-system/sw/bin 稳定路径：sudo 会把规则路径与
          # 实际命令都解析到真实 store 路径后比较，写死 /nix/store/...
          # 会因每次 rebuild 哈希变化而失配。
          # systemctl 不可无限制 NOPASSWD（`systemctl edit` 可逃逸拿 root shell），
          # 只放行远程调试必要的动词；status 普通用户本就可查，不放行。
          { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl restart *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl daemon-reload"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    # ── EasyTier 组网 ───────────────────────────────────────────────────
    # 与 VPS Hermes 建立 P2P 虚拟网络（IP 自动分配）
    # 密钥和 peer 由 root-only EnvironmentFile 在服务启动时注入，既不进入 Git，
    # 也不进入 world-readable Nix store。文件缺失时 ConditionPathExists 会跳过服务。
    services.easytier = {
      enable = true;

      instances.hao_link = {
        environmentFiles = [ myvars.easytierEnvironmentFile ];
        settings = {
          network_name = "hao_link";
          dhcp = true;
          inherit (myvars) hostname;

          listeners = [
            "tcp://0.0.0.0:11010"
            "udp://0.0.0.0:11010"
          ];
        };
      };
    };

    systemd.services.easytier-hao_link.unitConfig.ConditionPathExists =
      myvars.easytierEnvironmentFile;

    # ── 防火墙 ──────────────────────────────────────────────────────────
    networking.firewall = {
      # 密钥文件缺失时服务不会监听；存在时允许 EasyTier 建立 P2P 连接。
      allowedTCPPorts = [ 11010 ];
      allowedUDPPorts = [ 11010 ];
    };
  };
}
