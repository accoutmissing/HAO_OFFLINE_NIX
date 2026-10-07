# ── Hindsight 记忆服务 + 控制面（systemd 单元）────────────────
# Hindsight 不在 nixpkgs 里（PyPI: hindsight-all==0.9.1，配套 npm 控制面），
# 因此运行时环境按上游方式用 venv / node_modules 安装，systemd 单元则由本文件生成。
#
# 一次性初始化（在 HAO_WSL 内，root 执行）：
#   install -d -o hindsight -g hindsight /var/lib/hindsight /var/lib/hindsight-cp
#   sudo -u hindsight /run/current-system/sw/bin/python3.14 -m venv /var/lib/hindsight/venv
#   sudo -u hindsight /var/lib/hindsight/venv/bin/pip install \
#     -i https://pypi.tuna.tsinghua.edu.cn/simple hindsight-all==0.9.1
#   sudo -u hindsight npm install --prefix /var/lib/hindsight-cp \
#     --registry=https://registry.npmmirror.com @vectorize-io/hindsight-control-plane@0.9.1
#
# 环境变量（含 LLM / tenant 密钥）放 /etc/hindsight.env，权限 0600，不入 Git：
#   HINDSIGHT_API_LLM_PROVIDER / HINDSIGHT_API_LLM_API_KEY
#   HINDSIGHT_API_TENANT_EXTENSION / HINDSIGHT_API_TENANT_API_KEY
#   HF_ENDPOINT / HF_HUB_OFFLINE / HINDSIGHT_API_ENABLE_RERANKING
#   HINDSIGHT_API_RERANKER_PROVIDER / HINDSIGHT_API_SKIP_LLM_VERIFICATION
#   HOSTNAME / PORT / NODE_ENV / HINDSIGHT_CP_DATAPLANE_API_URL
#   HINDSIGHT_CP_ACCESS_KEY / HINDSIGHT_CP_DATAPLANE_API_KEY
#
# 数据：原 /home/hindsight（含 .pg0 内嵌 Postgres 数据、.cache 模型缓存）迁到
# /var/lib/hindsight，解包后需 chown -R hindsight:hindsight。
#
# ⚠️ 数据库迁移/还原的正确做法（2026-10-07 踩过的坑）：
#   把 pg_dump 导出的 SQL 直接 psql 到一个**已由应用迁移建好表**的库里，
#   表面只报 “relation already exists”，实际那张表的 COPY 数据不会进去——
#   当时 memory_units / memory_links / unit_entities / chunks 都是 0，
#   而 documents / entities 正常，看起来像“记忆全没了”。
#   正确步骤（实测 0 错误）：
#     systemctl stop hindsight hindsight-cp
#     sudo -u postgres psql -c 'DROP DATABASE hindsight WITH (FORCE);'
#     sudo -u postgres psql -c 'CREATE DATABASE hindsight OWNER hindsight;'
#     sudo -u postgres psql -d hindsight -v ON_ERROR_STOP=0 -f <dump.sql>
#   还原后核对行数：memory_units=204 / documents=28 / chunks=28 / entities=226 /
#   unit_entities=403 / memory_links=3269 / async_operations=62，
#   API 侧 /v1/default/banks 应显示 bank 的 fact_count=204。

{ config, lib, pkgs, ... }:

let
  stateDir = "/var/lib/hindsight";
  cpDir = "/var/lib/hindsight-cp";
  envFile = "/etc/hindsight.env";

  # 上游预编译产物需要的本地库：
  #   * Python wheels（tokenizers / torch / onnxruntime）经 dlopen 加载，
  #     靠 LD_LIBRARY_PATH 才能找到 libstdc++.so.6，nix-ld 对它无效
  #   * 内嵌 Postgres（pg0 预编译包）是被 exec 的二进制，由 nix-ld 负责；
  #     它需要 libicuuc.so.70（nixpkgs 的 icu70）、libzstd、liblz4、openssl、
  #     libgssapi_krb5、libxml2、liblzma 等
  nativeLibs = with pkgs; [
    stdenv.cc.cc.lib
    icu70
    zlib
    zstd
    lz4
    xz
    bzip2
    openssl
    krb5
    libxml2
    readline
    ncurses
  ];
  nativeLibPath = lib.makeLibraryPath nativeLibs;
in
{
  users.groups.hindsight.gid = 1510;
  users.users.hindsight = {
    isSystemUser = true;
    group = "hindsight";
    uid = 1510;
    home = stateDir;
    description = "Hindsight 记忆服务";
  };

  # ── 数据库：用 NixOS 原生 PostgreSQL + pgvector ───────────────
  # 不用上游的嵌入式 Postgres（pg0）：它是预编译包，在 NixOS 上需要 nix-ld、
  # 特定 ICU soname、/usr/share/zoneinfo 等一串兼容层，而且实测 pg0 返回的连接
  # URI 为 None（"PostgreSQL started: None"），应用拿不到数据库地址。
  # 改用系统 PostgreSQL 后，数据库本身由 Nix 声明式管理，升级/备份也更直接。
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18; # 与旧环境内嵌版本的大版本一致，便于数据搬迁
    extensions = ps: [ ps.pgvector ];
    ensureDatabases = [ "hindsight" ];
    ensureUsers = [
      {
        name = "hindsight";
        ensureDBOwnership = true;
      }
    ];
  };

  # 扩展需要建到具体库里（NixOS 只负责把扩展文件装好）
  systemd.services.hindsight-db-init = {
    description = "确保 hindsight 库存在 pgvector 扩展";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
    };
    script = ''
      # 首次激活时数据库可能还没建好（ensureDatabases 在 postgresql.service 的激活阶段完成），
      # 直接 psql 会报 database "hindsight" does not exist；这里自带重试，避免首启失败。
      for attempt in $(seq 1 30); do
        if ${config.services.postgresql.package}/bin/psql -d hindsight \
          -c 'CREATE EXTENSION IF NOT EXISTS vector;'; then
          exit 0
        fi
        echo "hindsight 库尚未就绪（第 $attempt 次重试），2 秒后继续..."
        sleep 2
      done
      echo "hindsight 库 60 秒内未就绪" >&2
      exit 1
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 hindsight hindsight -"
    "d ${cpDir} 0750 hindsight hindsight -"
    # 上游预编译的 Postgres 已不再使用（改用系统 PostgreSQL），但保留该链接
    # 以便其它预编译二进制按通用 Linux 布局查找时区库
    "d /usr/share 0755 root root -"
    "L+ /usr/share/zoneinfo - - - - /etc/zoneinfo"
  ];

  # Hindsight 依赖一批上游预编译二进制，NixOS 默认不提供它们的 loader/库路径：
  # 下面 nix-ld 负责“被 exec 的预编译二进制”（内嵌 Postgres 等），
  # 单元里的 LD_LIBRARY_PATH 负责“被 dlopen 的 Python 扩展”。
  programs.nix-ld = {
    enable = true;
    libraries = nativeLibs;
  };

  # ── 记忆服务（API，8888）─────────────────────────────────────────
  systemd.services.hindsight = {
    description = "Hindsight Agent Memory Server";
    after = [
      "network.target"
      "postgresql.service"
      "hindsight-db-init.service"
    ];
    wants = [ "hindsight-db-init.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "hindsight";
      Group = "hindsight";
      WorkingDirectory = stateDir;
      ExecStart = "${stateDir}/venv/bin/hindsight-api";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = envFile;
      Environment = [
        "LD_LIBRARY_PATH=${nativeLibPath}"
        # 本机 unix socket + peer 认证（服务以 hindsight 用户运行，角色同名）
        "HINDSIGHT_API_DATABASE_URL=postgresql://hindsight@/hindsight?host=/run/postgresql"
      ];
    };
  };

  # ── 控制面（Web UI，9999）───────────────────────────────────────
  systemd.services.hindsight-cp = {
    description = "Hindsight Control Plane (Web UI)";
    after = [ "network.target" "hindsight.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "hindsight";
      Group = "hindsight";
      WorkingDirectory = "${cpDir}/node_modules/@vectorize-io/hindsight-control-plane";
      ExecStart = "${pkgs.nodejs_22}/bin/node standalone/server.js";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = envFile;
      Environment = [ "PATH=${pkgs.nodejs_22}/bin" ];
    };
  };
}
