# ── 内存交换（低内存 VPS 防 OOM） ──────────────────────────────
{ lib, ... }:
{
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
