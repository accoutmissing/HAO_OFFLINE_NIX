# ── 服务器安全加固 ──────────────────────────────────────────────
# VPS（公网）与家庭服务器通用：
#   - fail2ban 防 SSH 爆破
#   - 防火墙默认拒绝 + 只放行必要端口
#   - 禁止 ping 响应（可选，防探测）
#   - 内核安全参数
{ lib, pkgs, ... }:
{
  # ── fail2ban：自动封禁暴力破解 IP ─────────────────────────────
  services.fail2ban = {
    enable = true;
    maxretry = 5;             # 5 次失败
    bantime = "1h";           # 封禁 1 小时
    ignoreIP = [
      "127.0.0.1/8"
      "::1/128"
    ];
  };

  # ── 防火墙（默认拒绝，显式放行） ──────────────────────────────
  networking.firewall = {
    enable = true;
    # 默认只放行 SSH（22）与 EasyTier（11010，由 easytier.nix 模块追加）
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
    # 拒绝 ping（防扫描；家庭内网可改回 true）
    allowPing = false;
  };

  # ── 内核安全参数 ───────────────────────────────────────────────
  boot.kernel.sysctl = {
    # 防 IP 欺骗 / 源路由攻击
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    # 禁 ICMP 重定向
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
  };

  # ── 其他 ───────────────────────────────────────────────────────
  # 关闭未使用的服务
  services.openssh.settings = {
    MaxAuthTries = 3;         # 每连接最多 3 次认证
    ClientAliveInterval = 300; # 5 分钟保活探测
    ClientAliveCountMax = 2;
  };
}
