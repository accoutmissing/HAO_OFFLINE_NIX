{ myvars, pkgs, ... }:
{
  # ── 许可：允许 unfree 包（NVIDIA 驱动 / Steam / Proton / Wine） ──
  nixpkgs.config.allowUnfree = true;

  # Nix 自身设置
  nix = {
    settings = {
      # 二进制缓存（与 flake.nix nixConfig 共用 myvars 定义）
      substituters = myvars.cachixSubstituters;
      trusted-public-keys = myvars.cachixTrustedPublicKeys;

      # 保持 Nix 默认的关闭状态；开启会用硬链接去重 store 文件，节省磁盘，
      # 但也增加文件扫描开销，可按本机磁盘空间和构建耗时决定。
      auto-optimise-store = false;

      experimental-features = [ "nix-command" "flakes" ];
      # admin 是有意授权的系统调试 Agent 账户；Nix trusted-users 等同 root 权限。
      trusted-users = [ "root" "@wheel" ];

      # 国内网络优化：超时缩短，避免因国际连接卡死
      download-attempts = 3;
      connect-timeout = 10;
    };

    # 不再按时间自动 GC：旧代由下方的容量触发服务统一管理，
    # 避免“7 天前”规则在容量仍有富余时提前删掉可回滚的版本。
  };

  # ── 按容量自动清理系统代 ────────────────────────────────────────────
  # 策略：/nix/store 未超过 50 GiB 时保留全部 generation（回滚深度优先）；
  # 超过后从最旧的 generation 开始删除并回收 dead paths，直到回到 50 GiB
  # 以内；始终保留当前代和上一代，且检测到 Nix 构建进行中时跳过。
  systemd.services.nixos-generation-prune = {
    description = "Prune old NixOS generations when the store exceeds 50 GiB";
    path = with pkgs; [ nix coreutils procps gawk ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail
      profile=/nix/var/nix/profiles/system
      limit=$((50 * 1024 * 1024 * 1024))
      store_size() { du -s --block-size=1 /nix/store | cut -f1; }

      if pgrep -x nix >/dev/null || pgrep -f 'nixos-rebuild' >/dev/null; then
        echo "Nix build in progress; skipping prune"
        exit 0
      fi

      size=$(store_size)
      echo "Current /nix/store usage: $size bytes (limit $limit)"
      if (( size <= limit )); then
        echo "Under limit; keeping all generations"
        exit 0
      fi

      mapfile -t gens < <(nix-env -p "$profile" --list-generations | awk '$1 ~ /^[0-9]+$/ { print $1+0 }')
      while (( size > limit && ''${#gens[@]} > 2 )); do
        oldest=''${gens[0]}
        echo "Deleting generation $oldest to free space"
        nix-env -p "$profile" --delete-generations "$oldest"
        nix-collect-garbage >/dev/null
        gens=("''${gens[@]:1}")
        size=$(store_size)
        echo "Store usage now: $size bytes"
      done

      if (( size > limit )); then
        echo "WARNING: still above limit with only ''${#gens[@]} generations; keeping current + previous for rollback"
      fi
    '';
  };

  systemd.timers.nixos-generation-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "3min";
      OnUnitActiveSec = "1h";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };

  # ── Nix daemon 代理 ────────────────────────────────────────────────
  # TUNA/USTC 镜像直连；回退到 cache.nixos.org、cachix 或 GitHub 时走本地
  # Clash Verge（mixed-port 7897），否则国际链路实测只有 20–30 KB/s。
  # 注意：Clash 未运行时 Nix 下载会直接失败（没有直连回退）。
  systemd.services.nix-daemon.environment = {
    http_proxy = "http://127.0.0.1:7897";
    https_proxy = "http://127.0.0.1:7897";
    all_proxy = "http://127.0.0.1:7897";
    HTTP_PROXY = "http://127.0.0.1:7897";
    HTTPS_PROXY = "http://127.0.0.1:7897";
    ALL_PROXY = "http://127.0.0.1:7897";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,mirrors.tuna.tsinghua.edu.cn,mirrors.ustc.edu.cn";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,mirrors.tuna.tsinghua.edu.cn,mirrors.ustc.edu.cn";
  };
}
