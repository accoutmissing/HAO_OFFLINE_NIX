_:
{
  # LocalSend 通过 TCP/UDP 53317 完成设备发现与传输，NixOS 防火墙默认拦截。
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];
}
