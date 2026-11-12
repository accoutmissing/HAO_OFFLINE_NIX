_:
{
  # 网络管理（桌面环境用 NetworkManager）
  networking.networkmanager.enable = true;

  # ── Intel Wireless-AC 9462 (CNVi) 稳定性 ───────────────────────────
  # 该卡会在省电状态切换/漫游时反复出现 802.11 认证超时，严重时 iwlwifi
  # 固件 ADVANCED_SYSASSERT / NMI_INTERRUPT_LMAC_FATAL 崩溃（wlo1 直接
  # 消失，只能冷启动恢复）。9000 系列固件 API 46 已是最后一版、无法再
  # 升级，只能减少触发条件：关掉 NM 和驱动两层的 WiFi 省电，并让 iwlmvm
  # 常驻 active 电源档，避免固件反复进入低功耗状态。
  networking.networkmanager.wifi.powersave = false; # false = 禁用省电（nixpkgs 26.11 起为布尔）

  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0 uapsd_disable=3
    options iwlmvm power_scheme=1
  '';
}
