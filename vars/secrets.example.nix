{
  # EasyTier 网络密钥（生成命令: openssl rand -hex 16）
  easytierNetworkSecret = "REPLACE_WITH_YOUR_SECRET";

  # EasyTier peer 列表（替换 <VPS_IP> 为你的 VPS 实际地址）
  easytierPeers = [
    "tcp://<VPS_IP>:11010"
    "tcp://public.easytier.top:11010"
    "tcp://c.oee.icu:60006"
    "tcp://47.121.195.130:11010"
  ];
}
