{ lib, ... }:
{
  # zram 压缩内存交换
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
