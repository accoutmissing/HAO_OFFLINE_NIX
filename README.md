# 🖥️ HAO NixOS 配置

一套 **Flake + Home Manager** 管理的 NixOS 配置，覆盖 **笔记本 + 台式机 + WSL** 三种场景，多台设备共享一套配置，各自只写硬件差异。

## ✨ 配置特点

| 类别 | 内容 |
|------|------|
| 🖥️ 主机 | HAO_OFFLINE（笔记本 i7-8750H + GTX 1060）/ HAO_DESKTOP（台式机 i5-13600KF + RTX 4070S）/ HAO_WSL（Windows WSL2） |
| 🪟 桌面 | Niri（滚动平铺 Wayland）+ Noctalia 壳层（bar/dock/启动器/锁屏）+ ReGreet 图形登录 |
| 💿 安装 | 中文全屏向导 + 按机型离线镜像 + 整盘分区；部分安装阶段可重试 |
| 🔤 中文输入 | Fcitx5 + Rime |
| 🎨 设计 | GIMP / Inkscape / Krita / Blender 全套 |
| 🛠️ 开发 | Node.js / Python / pnpm / lazygit / Starship 提示符 |
| 🤖 原生 AI | Codex / OpenCode / OMP，快捷呼出并保留终端会话 |
| 🎮 游戏 | Steam + Lutris + GameMode + MangoHud + Gamescope |
| 💬 通讯 | QQ / 微信（Linux 原生） |
| 🖥️ Windows 应用 | KVM/QEMU Windows VM（virt-manager / quickemu，swtpm + OVMF） |
| 🌐 网络 | EasyTier P2P 组网 + Clash Verge 代理 |
| 🐳 容器 | Podman（docker 兼容）+ libvirtd KVM |
| 🔒 安全 | SSH 禁密码、root 登录锁定、root-only 运行时 secrets；wheel 组拥有免密 sudo 和 Nix trusted-user 权限 |
| 🔄 系统 | Btrfs + zstd 压缩 + zram；桌面主机按 store 容量清理旧系统代，WSL 单独配置 GC |
| 🇨🇳 国内优化 | 清华/中科大镜像 + 超时优化 |
| 🔧 CI | GitHub Actions：格式/脚本/求值等快速检查始终运行；安装器 VM 测试仅安装器相关改动触发 |

每周 `update-flake-lock` 会创建 PR；仓库所有者需在 GitHub 的
`Settings → Actions → General → Workflow permissions` 启用
`Allow GitHub Actions to create and approve pull requests`。

## 🖥️ 主机一览

| 主机 | 机型 | 分支 | 说明 |
|------|------|------|------|
| **HAO_OFFLINE** | 神舟战神 Z7-KP7Z | main | i7-8750H + GTX 1060，Optimus 按需调用 |
| **HAO_DESKTOP** | 自组台式机 | main | i5-13600KF + RTX 4070S，独显常开 |
| **HAO_WSL** | Windows WSL2 | main | Penpot + Hindsight 常驻（声明式容器/systemd）；uid 1500 规避 WSL 用户会话缺陷 |
| **HAO_SERVER** | 家庭服务器 / VPS | — | 独立维护，不属于本仓库的 Flake 输出 |

### HAO_WSL Penpot 首次部署与密钥轮换

在 HAO_WSL 的仓库工作副本中，首次部署前生成并安装随机凭据，再切换系统：

```bash
bash scripts/setup.sh --penpot
mkpasswd -m yescrypt > secrets/admin-password-hash
sudo bash scripts/install-secrets.sh --penpot
sudo nixos-rebuild switch --flake .#HAO_WSL
```

`secrets/penpot.env` 与 `secrets/penpot-postgres.env` 被 Git 忽略；安装脚本校验应用与数据库密码相同，并安装为 root:root 0600。backend/exporter 只读取 Penpot 应用环境文件，PostgreSQL 只读取包含 `POSTGRES_PASSWORD` 的独立文件。机密值不写入 Nix 表达式或 Nix store。

PostgreSQL 官方镜像只在数据卷首次初始化时读取 `POSTGRES_PASSWORD`。如果检测到已有 `penpot_penpot_postgres_v15` 卷且本地两份凭据未匹配安装文件，安装脚本会拒绝普通安装。先做数据库备份，再生成轮换凭据并用 `--rotate-penpot-db`：它停止 backend/exporter，使用 psql 的 `\password` 从标准输入轮换 `penpot` 数据库角色密码，随后安装匹配的新环境文件并重启 backend / exporter / frontend 与 traefik（无需再跑 `nixos-rebuild switch`，生成的单元没有变化、switch 不会重启容器）；密码不会出现在命令参数或 PostgreSQL 明文语句日志中。该操作同时生成新的 `PENPOT_SECRET_KEY`，已有 Penpot 会话和邀请可能失效。轮换后再次运行普通安装会识别文件已匹配并成功退出。

```bash
umask 077
sudo docker exec penpot-postgres pg_dump -U penpot -d penpot > "$HOME/penpot-backup.sql"
bash scripts/setup.sh --penpot --rotate
sudo bash scripts/install-secrets.sh --rotate-penpot-db
sudo nixos-rebuild switch --flake .#HAO_WSL
```

请确认备份文件可读且内容完整后再执行轮换。安装脚本不会覆盖目标机已有的不同密钥；数据库轮换应在 HAO_WSL 本机对正在运行的 Postgres 容器执行。

## 🚀 快速开始

- 🐣 **第一次接触 Linux？** → [📖 安装入门指南（写给纯小白）](./INSTALL_GUIDE.md)
- 💿 **想直接制作 HAO 安装盘？** → [HAO Installer 构建与安全说明](./installer/README.md)
- 📦 **想用发布版本？** → [Releases](https://github.com/accoutmissing/HAO_OFFLINE_NIX/releases)

### HAO 安装向导

镜像正常启动图形会话后进入中文全屏界面，方向键选择、回车继续。确认机型、硬盘和密码后，向导会先准备完整系统，再清盘并安装；下载与系统安装阶段可重试，分区阶段不会自动重复执行。

国内安装建议使用匹配机型的离线版，安装现场无需联网下载系统；联网版会探测候选缓存并选择可达的源，包括官方缓存。图形界面启动失败时自动退回英文文字模式。

仓库中的安装器代码与已有 Release 镜像可能对应不同提交；使用前应核对镜像类型、构建提交和 SHA-256。镜像选择、分卷合并和 U 盘写入见[五步安装说明](./INSTALL_GUIDE.md#推荐五步完成安装)。

**安装验证状态：**曾在笔记本上遇到 Ventoy 介质识别和 EFI 分区挂载问题；实际机器上的恢复与启动验证不等于当前源码或新镜像已通过完整安装回归。尤其是旧文件系统签名及重复分区标签场景，安装前应核对安装器的修复和验证状态，勿将构建成功或 CI 通过视为实机安装通过。

当前版本只支持 **UEFI 整盘安装**，所选磁盘会被完全清空；双系统继续使用
[安装指南](./INSTALL_GUIDE.md) 中的高级手动流程。需要从源码构建 ISO 时运行：

```bash
nix build --accept-flake-config .#hao-installer-iso
```

生成文件位于 `result/iso/`。

## 🛠️ 常用操作

```bash
# 查看仓库定义
nix flake show

# 验证配置能解析，并确保 flake.lock 没有漏项
nix flake check --no-write-lock-file

# 首次使用：补齐 flake.lock 中缺失的锁定项
nix flake lock
# 需要更新已有依赖时再使用 nix flake update
git diff -- flake.lock
# 仅在存在预期的锁文件更改时提交
git add flake.lock && git commit -m "chore: update flake.lock"

# 更新系统（先确认 /var/lib/hao-secrets/admin-password-hash 已安装）
sudo nixos-rebuild switch --flake .#HAO_DESKTOP

# 回滚到上一个版本
sudo nixos-rebuild switch --rollback

# 手动清理 7 天前的旧代及不可达路径；可能减少可回滚代数
sudo nix-collect-garbage --delete-older-than 7d
# 桌面主机按容量检查旧系统代：目标为 50 GiB，保留回滚代可能仍超出
systemctl status nixos-generation-prune.timer
```

## 🧪 开发与 CI

在可写的仓库工作副本中修改并验证配置；下面以 `/etc/nixos` 为例，`nix fmt` 需要对工作副本有写权限：

```bash
cd /etc/nixos
nix fmt       # treefmt：nixpkgs-fmt / deadnix / statix / shellcheck / shfmt
nix flake check   # 完整检查，包含安装器 VM 测试
nixos-rebuild build --flake .#HAO_OFFLINE  # 构建配置，不切换系统
```

CI 分三层，避免基础设施抖动阻塞日常改动：

| Job | 触发条件 | 内容 |
|---|---|---|
| `changes` | 始终 | 根据 diff 判断是否触及安装器相关路径 |
| `check` | 始终 | formatting、installer 脚本测试、三主机 + 三个 ISO 求值、NVIDIA 模块构建 |
| `installer-vm` | 仅安装器相关改动 | 完整安装流程 VM 测试；失败自动重试一次 |

触发 VM 测试的路径：`installer/**`、`tests/**`、`hosts/**`、`modules/nixos/base/**`、`vars/**`、`flake.nix`、`flake.lock`。只改桌面模块（`modules/nixos/desktop/**`）不会触发 VM 测试。

**本地覆盖**：`hosts/<host>/local.nix` 被 `.gitignore` 忽略，不会进入仓库。git 模式的 flake 不打包未跟踪文件，所以启用本地覆盖后请用 `path:` 重建：

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#HAO_OFFLINE
```

CI 使用 git 检出，天然不包含 `local.nix`，这就是“特例不进仓库”的保证。

看到 CI 失败应先看具体步骤和日志；安装器 VM 测试曾出现进程被 `SIGKILL` 的情况，原因不一定是代码错误，也不能仅凭红灯断定是资源不足。重跑可帮助定位，但不能替代对失败原因的分析。CI、构建、实际切换与安装是不同验证阶段，应分别记录结果。

## 🎮 游戏与 Windows VM

- Steam 已声明安装 GE-Proton；按游戏在「属性 → 兼容性」中选择。日用 Windows 程序可使用 Wine 11。
- 笔记本的 Gamescope 启动器会为游戏启用 NVIDIA PRIME offload；普通 Steam 游戏可设置启动选项 `nvidia-offload %command%`。桌面仍默认使用核显。
- Linux 6.14 及以上默认加载 NTSYNC，并允许普通用户访问 `/dev/ntsync`。可设置 `modules.desktop.gaming.ntsync.enable = false;` 重建并重启，比较具体游戏的帧时间；设备存在不代表每个 Wine/Proton 版本都会使用它。
- virt-manager 默认连接系统 libvirt；宿主机关机时向 VM 发送关机请求，下次开机不恢复上次会话。单独标记为 autostart 的 VM 仍会自动启动。
- 已定义的 libvirt `default` NAT 网络会自动启动；没有定义时服务会跳过，可在 virt-manager 中创建所需网络。
- 笔记本提供 `/var/lib/ovmf/OVMF_CODE.fd`、`OVMF_VARS.fd` 和 `OVMF_VARS.ms.fd`。CODE 是只读固件，VARS 是只读模板，libvirt 应为每台 VM 创建独立的可写 NVRAM；微软密钥模板还需配合 VM 的 Secure Boot 和 TPM 设置。

实现依据：[libvirt NVRAM 模板](https://libvirt.org/formatdomain.html#bios-bootloader)、[GE-Proton NTSYNC 要求](https://github.com/GloriousEggroll/proton-ge-custom#enabling-ntsync)。

## 🤖 原生 AI Agent

桌面配置内置了类似 Omarchy 的原生 AI 入口，但适配为 Niri + Noctalia：

- 按 `Win + Shift + Ctrl + A` 呼出或隐藏顶部浮动的 Agent 窗口；再次打开会保留之前的会话。
- 按 `Win + 空格` 搜索 **HAO AI** 也可以启动。
- 无已保存的有效选择时默认使用 OpenCode；运行 `ai-pick` 可临时选择 Codex、OpenCode 或 OMP。
- 运行 `hao-agent --current` 查看当前选择，或运行 `hao-agent --set omp` 修改默认 Agent；支持值为 `codex`、`opencode`、`omp`。

第一次使用某个 Agent 时，在终端完成它自己的登录：

```bash
codex login
omp   # 启动后输入 /login 登录
opencode auth login
```

各 CLI 的登录与命令确认行为取决于其版本及用户配置；请勿将凭据提交到仓库或写入 Nix 表达式。权限提示不能替代系统隔离。
`omp` 由 oh-my-pi 的 Flake 源码构建，输入由 `flake.lock` 固定；项目还启用了上游 Home Manager 模块。需要更新时执行 `nix flake update oh-my-pi`，检查锁文件与变更后重新构建；源码构建可能耗时较长。

当前配置允许 wheel 组免密 sudo，且将 `@wheel` 列为 Nix trusted-users；以该组用户身份运行的 Agent 可能获得系统级权限。`admin` 账户及其 SSH 密钥应按 root 权限保护，运行前请检查各 Agent 的权限设置。

## 📚 相关链接

| 资源 | 说明 |
|------|------|
| [📖 安装入门指南](./INSTALL_GUIDE.md) | 零基础手把手安装教程（桌面 + 服务器） |
| [NixOS 官方文档](https://nixos.org/manual/nixos/stable/) | 权威参考 |
| [nixos-and-flakes-book](https://github.com/ryan4yin/nixos-and-flakes-book) | 中文 Flakes 入门书 |
| [Noctalia](https://noctalia.dev) | 桌面壳层 |
| [Niri](https://github.com/niri-wm/niri) | 滚动平铺 Wayland 合成器 |
| [disko](https://github.com/nix-community/disko) | 声明式分区工具 |
| [EasyTier](https://github.com/EasyTier/EasyTier) | P2P 组网 |

---

> 💡 安装细节、分区方案、双系统/虚拟机部署全部在 [INSTALL_GUIDE.md](./INSTALL_GUIDE.md) 中，本 README 只介绍配置本身。
