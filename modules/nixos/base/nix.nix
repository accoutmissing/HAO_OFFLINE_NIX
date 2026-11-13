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

    # 自动 GC（每周清理 7 天前的旧版本）
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ── 自动清理旧系统代 ────────────────────────────────────────────────
  # 频繁 rebuild 会在同一天留下大量 generation；`nix.gc` 只按“7 天前”删除，
  # 对当天的迭代无能为力。这里每天保留最新 5 代 + 最初安装代，其余删除，
  # 然后回收死路径；检测到 Nix 构建进行中则跳过，避免与重建竞争。
  systemd.services.nixos-generation-prune = {
    description = "Prune old NixOS generations and collect garbage";
    path = with pkgs; [ nix coreutils procps gawk ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail
      profile=/nix/var/nix/profiles/system
      if pgrep -x nix >/dev/null || pgrep -f 'nixos-rebuild' >/dev/null; then
        echo "Nix build in progress; skipping prune"
        exit 0
      fi
      mapfile -t gens < <(nix-env -p "$profile" --list-generations | awk '$1 ~ /^[0-9]+$/ { print $1+0 }')
      count=''${#gens[@]}
      keep=5
      if (( count > keep + 1 )); then
        delete=("''${gens[@]:1:count-keep-1}")
        echo "Deleting generations: ''${delete[*]}"
        nix-env -p "$profile" --delete-generations "''${delete[@]}"
      else
        echo "Only $count generations; nothing to prune"
      fi
      nix-collect-garbage >/dev/null
    '';
  };

  systemd.timers.nixos-generation-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
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
