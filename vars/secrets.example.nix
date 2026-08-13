{
  # 初始登录密码哈希（mkpasswd -m yescrypt 生成，$y$ 开头）
  # ⚠️ 不填（保持 null）时安装会被 assertion 阻止，避免装完锁死无法登录
  initialHashedPassword = null;

  # EasyTier 网络密钥（生成命令: openssl rand -hex 16）
  easytierNetworkSecret = "REPLACE_WITH_YOUR_SECRET";

  # EasyTier peer 列表（替换 <YOUR_VPS_IP> 为你的 VPS 实际地址）
  easytierPeers = [
    "tcp://<YOUR_VPS_IP>:11010"
    "tcp://public.easytier.top:11010"
    "tcp://<YOUR_VPS_IP>:60006"
    "udp://<YOUR_VPS_IP>:11010"
  ];
}
