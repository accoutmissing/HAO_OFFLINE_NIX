# ── Penpot（声明式容器编排）──────────────────────────────────
# 由原 Ubuntu 的 docker compose（Penpot 官方 compose 2.17.1 + traefik 反代）翻译而来。
#
# 与 compose 的对应关系与有意差异：
#   * 网络：compose 的 `penpot` 网络 → 这里手工创建同名 docker network，
#     容器名与 compose 的 service 名一致（penpot-postgres / penpot-valkey /
#     penpot-mailcatch / penpot-frontend），因此后端里引用的主机名无需改动。
#   * 卷：沿用 compose 的命名卷（penpot_penpot_assets / penpot_penpot_postgres_v15），
#     用 --mount 挂载。assets 卷里的文件属主是 1001:1001（Penpot 镜像内的用户），
#     从旧环境用 tar 还原时保留数字属主即可。
#   * healthcheck / depends_on(condition: service_healthy)：oci-containers 不支持，
#     改为 systemd 单元顺序 + 容器重启策略，Postgres 就绪前后端会自行重试。
#   * Penpot 应用机密从 /var/lib/hao-secrets/penpot.env 注入；PostgreSQL
#     初始化密码单独从 /var/lib/hao-secrets/penpot-postgres.env 注入。
#     两个文件由 scripts/install-secrets.sh 安装为 root:root 0600。
#     已有数据库不会因 POSTGRES_PASSWORD 改变而自动轮换角色密码，轮换步骤见 README。
#
# 证书不在 Git 里：/var/lib/penpot/certs/{penpot.crt,penpot.key} 优先从旧环境复制；
# 缺失时由 penpot-certs.service 自动生成自签名证书（SAN 含探测到的局域网 IP）——
# 浏览器会提示不受信任，与旧环境本地 CA（penpot-local-ca.crt，仅用于浏览器信任）
# 方案同等效力；将生成的证书或本地 CA 导入信任存储即可消除提示。

{ lib, pkgs, ... }:

let
  version = "2.17.1";
  mirror = "docker.m.daocloud.io"; # 国内可达的镜像前缀，与原 compose 一致
  penpotImage = name: "${mirror}/penpotapp/${name}:${version}";

  network = "penpot";
  netOpt = "--network=${network}";

  certsDir = "/var/lib/penpot/certs";
  penpotSecretsFile = "/var/lib/hao-secrets/penpot.env";
  postgresSecretsFile = "/var/lib/hao-secrets/penpot-postgres.env";

  # 运行时探测生成的环境文件（/run 为 tmpfs，内容因机器而异，不入 Git）；
  # 容器经 --env-file 注入，避免把某台机器的局域网 IP 硬编码进仓库。
  publicUriEnvFile = "/run/penpot-public-uri.env";
  publicUriOpt = "--env-file=${publicUriEnvFile}";

  # 局域网 IP 探测脚本：penpot-public-uri.service 与三个容器的 preStart 共用。
  # 容器 preStart 引用其 store 路径：探测逻辑变化 → 单元内容变化 → 切换时
  # 自动重启相关容器，保证容器创建前读到的一定是最新探测值。
  detectLanIp = pkgs.writeShellScript "penpot-detect-lan-ip" ''
    ip=
    # 1) EasyTier 组网网段的本机地址（各机器的稳定组网地址，按机器自动适配）
    ip="$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global 2>/dev/null | ${pkgs.gawk}/bin/awk '$4 ~ /^10\.144\.144\./ { sub(/\/.*/, "", $4); print $4; exit }')" || ip=
    if [ -z "$ip" ]; then
      # 2) 默认路由源地址，仅接受 RFC1918 私网（排除 198.18.x TUN 与公网）
      ip="$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')" || ip=
      case "$ip" in
        10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;;
        *) ip= ;;
      esac
    fi
    if [ -z "$ip" ]; then
      # 3) 首个私网全局地址（跳过 lo/docker/bridge）
      ip="$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global 2>/dev/null | ${pkgs.gawk}/bin/awk '$2 !~ /^(lo|docker|br-|veth)/ && ($4 ~ /^10\./ || $4 ~ /^192\.168\./ || $4 ~ /^172\.(1[6-9]|2[0-9]|3[01])\./) { sub(/\/.*/, "", $4); print $4; exit }')" || ip=
    fi
    if [ -z "$ip" ]; then
      ip=127.0.0.1
    fi
    echo "PENPOT_PUBLIC_URI=https://''${ip}:9001" > ${publicUriEnvFile}
    echo "penpot-detect-lan-ip: ''${ip}"
  '';

  # 确保 traefik 证书存在：已有证书（旧环境复制）则直接使用；docker 在 -v 源
  # 路径缺失时会创建“目录占位”，先清理；否则以探测到的局域网 IP 为 SAN 自签。
  ensurePenpotCerts = pkgs.writeShellScript "ensure-penpot-certs" ''
    crt=${certsDir}/penpot.crt
    key=${certsDir}/penpot.key
    for f in "$crt" "$key"; do
      if [ -d "$f" ]; then
        echo "penpot-certs: removing docker-created directory placeholder ''${f}"
        rm -rf "$f"
      fi
    done
    if [ -f "$crt" ] && [ -f "$key" ]; then
      echo "penpot-certs: using existing certificate"
      exit 0
    fi
    ip="$(sed -n 's|^PENPOT_PUBLIC_URI=https://\([0-9.]*\):9001$|\1|p' ${publicUriEnvFile})"
    if [ -z "$ip" ]; then
      ip=127.0.0.1
    fi
    echo "penpot-certs: generating self-signed certificate for ''${ip}"
    ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
      -keyout "$key" -out "$crt" \
      -subj "/CN=''${ip}" \
      -addext "subjectAltName=IP:''${ip},IP:127.0.0.1,DNS:localhost"
    chmod 600 "$key"
    chmod 644 "$crt"
  '';

  assetsMount = "--mount=type=volume,src=penpot_penpot_assets,dst=/opt/data/assets";
  postgresMount = "--mount=type=volume,src=penpot_penpot_postgres_v15,dst=/var/lib/postgresql/data";

  penpotFlags = {
    # disable-telemetry：默认 telemetry 开着，会向 Penpot 官方端点发遥测请求
    # （国内网络下易超时重试、占后台 worker）。flag 命名规则为 <enable|disable>-<flag>。
    PENPOT_FLAGS =
      "disable-email-verification enable-smtp enable-prepl-server disable-secure-session-cookies enable-mcp disable-telemetry";
    # PENPOT_PUBLIC_URI 不再硬编码机器 IP：由 detectLanIp 脚本运行时探测本机
    # 局域网 IP（EasyTier 组网网段优先）写入 env 文件，经 --env-file 注入。
    PENPOT_HTTP_SERVER_MAX_BODY_SIZE = "367001600";
    PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE = "367001600";
  };

  containers = {
    penpot-postgres = {
      image = "${mirror}/library/postgres:15";
      environment = {
        POSTGRES_INITDB_ARGS = "--data-checksums";
        POSTGRES_DB = "penpot";
        POSTGRES_USER = "penpot";
      };
      environmentFiles = [ postgresSecretsFile ];
      extraOptions = [ netOpt "--stop-signal=SIGINT" postgresMount ];
    };

    penpot-valkey = {
      image = "${mirror}/valkey/valkey:8.1";
      environment.VALKEY_EXTRA_FLAGS = "--maxmemory 128mb --maxmemory-policy volatile-lfu";
      extraOptions = [ netOpt ];
    };

    penpot-mailcatch = {
      image = "${mirror}/sj26/mailcatcher:latest";
      ports = [ "1080:1080" ];
      extraOptions = [ netOpt ];
    };

    penpot-backend = {
      image = penpotImage "backend";
      dependsOn = [ "penpot-postgres" "penpot-valkey" ];
      environment = penpotFlags // {
        PENPOT_DATABASE_URI = "postgresql://penpot-postgres/penpot";
        PENPOT_DATABASE_USERNAME = "penpot";
        PENPOT_REDIS_URI = "redis://penpot-valkey/0";
        PENPOT_OBJECTS_STORAGE_BACKEND = "fs";
        PENPOT_OBJECTS_STORAGE_FS_DIRECTORY = "/opt/data/assets";
        PENPOT_TELEMETRY_ENABLED = "true";
        PENPOT_TELEMETRY_REFERER = "compose";
        PENPOT_SMTP_DEFAULT_FROM = "no-reply@example.com";
        PENPOT_SMTP_DEFAULT_REPLY_TO = "no-reply@example.com";
        PENPOT_SMTP_HOST = "penpot-mailcatch";
        PENPOT_SMTP_PORT = "1025";
        PENPOT_SMTP_TLS = "false";
        PENPOT_SMTP_SSL = "false";
      };
      environmentFiles = [ penpotSecretsFile ];
      extraOptions = [ netOpt assetsMount publicUriOpt ];
    };

    penpot-exporter = {
      image = penpotImage "exporter";
      dependsOn = [ "penpot-valkey" ];
      environment = {
        PENPOT_INTERNAL_URI = "http://penpot-frontend:8080";
        PENPOT_REDIS_URI = "redis://penpot-valkey/0";
      };
      environmentFiles = [ penpotSecretsFile ];
      extraOptions = [ netOpt publicUriOpt ];
    };

    penpot-mcp = {
      image = penpotImage "mcp";
      extraOptions = [ netOpt ];
    };

    penpot-frontend = {
      image = penpotImage "frontend";
      dependsOn = [ "penpot-backend" "penpot-exporter" "penpot-mcp" ];
      environment = penpotFlags;
      labels = {
        "traefik.enable" = "true";
        "traefik.docker.network" = network;
        "traefik.http.routers.penpot.rule" = "PathPrefix(`/`)";
        "traefik.http.routers.penpot.entrypoints" = "websecure";
        "traefik.http.routers.penpot.tls" = "true";
        "traefik.http.services.penpot.loadbalancer.server.port" = "8080";
      };
      extraOptions = [ netOpt assetsMount publicUriOpt ];
    };

    traefik = {
      image = "${mirror}/traefik:latest"; # 需用 latest：旧 tag 的 docker client API 过旧
      dependsOn = [ "penpot-frontend" ];
      cmd = [
        "--providers.docker=true"
        "--providers.docker.exposedbydefault=false"
        "--providers.file.filename=/etc/traefik/dynamic.yml"
        "--providers.file.watch=true"
        "--entryPoints.websecure.address=:9001"
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "${certsDir}/penpot.crt:/certs/penpot.crt:ro"
        "${certsDir}/penpot.key:/certs/penpot.key:ro"
        "/etc/penpot/traefik-dynamic.yml:/etc/traefik/dynamic.yml:ro"
      ];
      ports = [ "9001:9001" ];
      extraOptions = [ netOpt ];
    };
  };
in
{
  # ── 容器运行时 ────────────────────────────────────────────────────
  virtualisation.docker.enable = true;

  # compose 的默认证书文件（traefik 默认 TLS 证书），非机密，可入 Git
  environment.etc."penpot/traefik-dynamic.yml".text = ''
    tls:
      stores:
        default:
          defaultCertificate:
            certFile: /certs/penpot.crt
            keyFile: /certs/penpot.key
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/penpot 0755 root root -"
    "d ${certsDir} 0755 root root -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    inherit containers;
  };

  # ── 共享网络：容器名即 compose 的 service 名，靠它互相解析；容器须待网络就绪 ──
  systemd.services = {
    penpot-network = {
      description = "创建 Penpot 容器网络";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.docker}/bin/docker network inspect ${network} >/dev/null 2>&1 \
          || ${pkgs.docker}/bin/docker network create ${network}
      '';
    };
    # 运行时探测本机局域网 IP 并生成 Penpot PUBLIC_URI 环境文件（自动适配每台机器）：
    #   1) EasyTier 组网网段 10.144.144.0/24 的本机地址（组网约定，各机器的稳定地址）
    #   2) 默认路由源地址（仅接受 RFC1918 私网；排除 Clash 等 TUN 的 198.18.x 与公网地址）
    #   3) 首个私网全局地址（跳过 lo/docker/bridge）   4) 127.0.0.1 兜底
    # 注：WSL 镜像网络会把 Windows 适配器改名为 ethN（接口名丢失），故按 IP 网段而非
    #     接口名识别。容器单元经下方 genAttrs 在本单元之后启动，保证 --env-file 读取时文件已生成。
    penpot-public-uri = {
      description = "Detect LAN IP and generate Penpot PUBLIC_URI env file";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = detectLanIp;
        RemainAfterExit = true;
      };
    };

    # TLS 证书：优先使用复制来的证书；缺失时自动生成自签名证书（跨机器自适配）。
    # SAN 取自 penpot-public-uri.env 探测到的局域网 IP，排在 traefik 之前执行。
    penpot-certs = {
      description = "Ensure Penpot traefik TLS certificate (self-signed fallback)";
      after = [ "network-online.target" "penpot-public-uri.service" ];
      wants = [ "network-online.target" "penpot-public-uri.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ensurePenpotCerts;
        RemainAfterExit = true;
      };
    };
  } // lib.genAttrs (map (name: "docker-${name}") (lib.attrNames containers)) (unitName:
    let
      cname = lib.removePrefix "docker-" unitName;
    in
    {
      after = [ "penpot-network.service" "penpot-public-uri.service" "penpot-certs.service" ];
      wants = [ "penpot-network.service" "penpot-public-uri.service" "penpot-certs.service" ];
    }
    // lib.optionalAttrs (builtins.elem cname [ "penpot-postgres" "penpot-backend" "penpot-frontend" "penpot-exporter" ]) {
      preStart = ''
        ${lib.optionalString (builtins.elem cname [ "penpot-postgres" "penpot-backend" "penpot-exporter" ]) ''
          secrets_file=${if cname == "penpot-postgres" then postgresSecretsFile else penpotSecretsFile}
          if [ ! -f "$secrets_file" ] || [ -L "$secrets_file" ]; then
            echo "Penpot secrets missing: run bash scripts/setup.sh --penpot, then sudo bash scripts/install-secrets.sh --penpot (use --rotate-penpot-db for an existing database)." >&2
            exit 1
          fi
          if [ "$(${pkgs.coreutils}/bin/stat -c '%a:%U:%G' "$secrets_file")" != "600:root:root" ]; then
            echo "Penpot secrets must be owned by root:root with mode 0600: $secrets_file" >&2
            exit 1
          fi
        ''}
        ${lib.optionalString (builtins.elem cname [ "penpot-backend" "penpot-frontend" "penpot-exporter" ]) "exec ${detectLanIp}"}
      '';
    });
}
