# HAO_WSL 的 Windows 侧设置

本目录存放 NixOS 发行版之外的 Windows 宿主机配置，保证换机或重装后能按同一套流程复现。
Penpot / Hindsight / 数据库的服务配置见 `../services/`。Hindsight 的 venv、npm
依赖和应用数据仍在 `/var/lib` 中，需按模块注释另行初始化和备份。

## 1. 导入发行版

NixOS 不在 `wsl --install` 的官方发行版列表里，必须用 tarball 导入：

```powershell
# 下载官方镜像与校验文件
curl.exe -L -o C:\Users\admin\wsl\nixos.wsl `
  https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl
curl.exe -L -o C:\Users\admin\wsl\nixos.wsl.sha256 `
  https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl.sha256
# 校验（2026-10 实测版本 2605.7.2，sha256 e7180ad5…f6b9）
certutil -hashfile C:\Users\admin\wsl\nixos.wsl SHA256

wsl --import HAO_WSL C:\Users\admin\wsl\HAO_WSL C:\Users\admin\wsl\nixos.wsl --version 2
wsl --set-default HAO_WSL
```

套用本仓库配置（镜像内没有 git 二进制，用 `github:` 形式即可）：

```powershell
wsl -d HAO_WSL -u root -- nixos-rebuild switch --flake github:accoutmissing/HAO_OFFLINE_NIX#HAO_WSL
```

> 刚推送后用 `github:` 重建会命中约 1 小时的 flake 解析缓存，拿到旧 revision，需要加 `--refresh`。

## 2. `.wslconfig`（本机 `C:\Users\admin\.wslconfig`）

见同目录 `.wslconfig` 模板。要点：

- `networkingMode=mirrored`：发行版与 Windows 共享局域网 IP，Penpot/Hindsight 直接以
  `10.144.144.7:9001|8888|9999` 提供服务，不需要 `netsh portproxy`
- `memory=12GB`、`processors=8`：当前宿主机的资源上限，换机时按可用资源调整
- `[general] instanceIdleTimeout=-1`：禁用发行版空闲自动退出
- `vmIdleTimeout=86400000`：WSL 虚拟机空闲超时为 24 小时，单位为毫秒

## 3. 常驻设置与保活脚本

微软当前文档提供 `[general] instanceIdleTimeout`：默认 15000 毫秒，设为 `-1`
可禁用发行版空闲自动退出。模板已配置该项；`vmIdleTimeout` 管的是整个 WSL 虚拟机，
两者不能混为一谈。单独启动 systemd 服务也不会保证 WSL 常驻。
见 [微软配置文档](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)。

保留 `wsl-keepalive.ps1` 作为旧版 WSL 的兼容兜底，它循环挂一个长命令：

```powershell
while ($true) { wsl.exe -d HAO_WSL -u root -- /run/current-system/sw/bin/sleep 600 | Out-Null }
```

每 10 分钟续一次会话，VM 若被关掉则下一轮自动重新拉起；脚本带命名互斥量，重复启动会立即退出。
调用失败时等待 10 秒，避免不断重试。脚本使用 ASCII 注释，以免 Windows PowerShell 5.1
按本地编码读取无 BOM 的 UTF-8 文件时产生歧义。

## 4. 登录自启（两个入口，互为兜底）

| 入口 | 内容 | 备注 |
| --- | --- | --- |
| 计划任务 `WSL_Auto_Start` | `powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\admin\wsl-keepalive.ps1` | 触发器=登录时；已关闭电池/空闲停止、执行时长上限 PT0S、多实例 IgnoreNew。用 `wsl-task-update.ps1` 提权重建 |
| 启动文件夹 | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\wsl-hao-wsl.bat` | 免提权，拉起同一脚本；重复启动由互斥量挡掉 |

## 5. 文件归属

| 文件 | 用途 |
| --- | --- |
| `.wslconfig` | 模板，复制到 `C:\Users\admin\.wslconfig` |
| `wsl-keepalive.ps1` | 保活主脚本（复制到 `C:\Users\admin\`） |
| `wsl-hao-wsl.bat` | 启动文件夹条目（复制到 Startup 目录） |
| `wsl-task-update.ps1` | 提权重建/修复 `WSL_Auto_Start` 计划任务 |
| `wsl-keepalive-verify.ps1` | 自检：任务定义、保活实例数、发行版状态、三个服务端点 |

## 6. 不在本仓库的东西（机器侧，需单独备份）

- `/etc/hindsight.env`：Hindsight 的 LLM key、tenant key、控制面 key（0600，不入 Git）
- `/var/lib/penpot/certs/{penpot.crt,penpot.key}`：Penpot 的 TLS 证书与私钥
- 数据卷 `penpot_penpot_assets`、`penpot_penpot_postgres_v15` 与 PostgreSQL 18 的 `hindsight` 库
