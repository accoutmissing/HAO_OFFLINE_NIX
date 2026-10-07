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
#   * PENPOT_SECRET_KEY 保持旧环境的 compose 默认值，避免既有登录会话失效。
#
# 证书不在 Git 里：/var/lib/penpot/certs/{penpot.crt,penpot.key} 需从旧环境复制
# （另外同目录的 penpot-local-ca.crt 是本地 CA，仅用于浏览器信任，traefik 不需要）。

{ lib, pkgs, ... }:

let
  version = "2.17.1";
  mirror = "docker.m.daocloud.io"; # 国内可达的镜像前缀，与原 compose 一致
  penpotImage = name: "${mirror}/penpotapp/${name}:${version}";

  network = "penpot";
  netOpt = "--network=${network}";

  certsDir = "/var/lib/penpot/certs";

  assetsMount = "--mount=type=volume,src=penpot_penpot_assets,dst=/opt/data/assets";
  postgresMount = "--mount=type=volume,src=penpot_penpot_postgres_v15,dst=/var/lib/postgresql/data";

  penpotFlags = {
    # disable-telemetry：默认 telemetry 开着，会向 Penpot 官方端点发遥测请求
    # （国内网络下易超时重试、占后台 worker）。flag 命名规则为 <enable|disable>-<flag>。
    PENPOT_FLAGS =
      "disable-email-verification enable-smtp enable-prepl-server disable-secure-session-cookies enable-mcp disable-telemetry";
    PENPOT_PUBLIC_URI = "https://10.144.144.7:9001";
    PENPOT_HTTP_SERVER_MAX_BODY_SIZE = "367001600";
    PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE = "367001600";
  };

  penpotSecretKey = {
    PENPOT_SECRET_KEY = "change-this-insecure-key";
  };

  containers = {
    penpot-postgres = {
      image = "${mirror}/library/postgres:15";
      environment = {
        POSTGRES_INITDB_ARGS = "--data-checksums";
        POSTGRES_DB = "penpot";
        POSTGRES_USER = "penpot";
        POSTGRES_PASSWORD = "penpot";
      };
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
      environment = penpotFlags // penpotSecretKey // {
        PENPOT_DATABASE_URI = "postgresql://penpot-postgres/penpot";
        PENPOT_DATABASE_USERNAME = "penpot";
        PENPOT_DATABASE_PASSWORD = "penpot";
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
      extraOptions = [ netOpt assetsMount ];
    };

    penpot-exporter = {
      image = penpotImage "exporter";
      dependsOn = [ "penpot-valkey" ];
      environment = penpotSecretKey // {
        PENPOT_PUBLIC_URI = "https://10.144.144.7:9001";
        PENPOT_INTERNAL_URI = "http://penpot-frontend:8080";
        PENPOT_REDIS_URI = "redis://penpot-valkey/0";
      };
      extraOptions = [ netOpt ];
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
      extraOptions = [ netOpt assetsMount ];
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
  } // lib.genAttrs (map (name: "docker-${name}") (lib.attrNames containers)) (_: {
    after = [ "penpot-network.service" ];
    wants = [ "penpot-network.service" ];
  });
}
