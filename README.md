# 🖥️ HAO NixOS 配置

一套 **Flake + Home Manager** 管理的 NixOS 配置，覆盖 **笔记本 + 台式机 + WSL + 服务器** 四种场景，多台设备共享一套配置，各自只写硬件差异。

## ✨ 配置特点

| 类别 | 内容 |
|------|------|
| 🖥️ 主机 | HAO_OFFLINE（笔记本 i7-8750H + GTX 1060）/ HAO_DESKTOP（台式机 i5-13600KF + RTX 4070S）/ HAO_SERVER（服务器，独立分支） |
| 🪟 桌面 | Niri（滚动平铺 Wayland）+ Noctalia 壳层（bar/dock/启动器/锁屏）+ ReGreet 图形登录 |
| 💿 安装 | HAO 全屏安装向导 + Disko 自动分区 + 首次登录欢迎提示 |
| 🔤 中文输入 | Fcitx5 + Rime |
| 🎨 设计 | GIMP / Inkscape / Krita / Blender 全套 |
| 🛠️ 开发 | Node.js / Python / pnpm / lazygit / Starship 提示符 |
| 🤖 原生 AI | Codex / Claude Code / OpenCode，快捷呼出并保留终端会话 |
| 🎮 游戏 | Steam + Lutris + GameMode + MangoHud + Gamescope |
| 💬 通讯 | QQ / 微信（Linux 原生） |
| 🖥️ Windows 应用 | KVM/QEMU Windows VM（virt-manager / quickemu，swtpm + OVMF） |
| 🌐 网络 | EasyTier P2P 组网 + Clash Verge 代理 |
| 🐳 容器 | Podman（docker 兼容）+ libvirtd KVM |
| 🔒 安全 | SSH 禁密码 + root 锁定 + root-only 运行时 secrets（不进 Git / Nix store） |
| 🔄 系统 | Btrfs + zstd 压缩 + zram + 每周自动 GC |
| 🇨🇳 国内优化 | 清华/中科大镜像 + 超时优化 |
| 🔧 CI | GitHub Actions `nix flake check` + 四主机/ISO eval + Release ISO 构建 |

每周 `update-flake-lock` 会创建 PR；仓库所有者需在 GitHub 的
`Settings → Actions → General → Workflow permissions` 启用
`Allow GitHub Actions to create and approve pull requests`。

## 🖥️ 主机一览

| 主机 | 机型 | 分支 | 说明 |
|------|------|------|------|
| **HAO_OFFLINE** | 神舟战神 Z7-KP7Z | main | i7-8750H + GTX 1060，Optimus 按需调用 |
| **HAO_DESKTOP** | 自组台式机 | main | i5-13600KF + RTX 4070S，独显常开 |
| **HAO_WSL** | Windows WSL2 | main | Penpot + Hindsight 常驻（声明式容器/systemd）；uid 1500 规避 WSL 用户会话缺陷 |
| **HAO_SERVER** | 家庭服务器 / VPS | **HAO_SERVER** | 无头服务器，fail2ban + 容器 + 自动更新 |

## 🚀 快速开始

- 🐣 **第一次接触 Linux？** → [📖 安装入门指南（写给纯小白）](./INSTALL_GUIDE.md)
- 💿 **想直接制作 HAO 安装盘？** → [HAO Installer 构建与安全说明](./installer/README.md)
- ⚙️ **想按已有教程装系统？** → 参考 [README 旧版安装说明](https://github.com/accoutmissing/HAO_OFFLINE_NIX/blob/main/README.md)（已迁移至 INSTALL_GUIDE）
- 📦 **想用发布版本？** → [Releases](https://github.com/accoutmissing/HAO_OFFLINE_NIX/releases)

### HAO 图形化安装向导

Release 中的 `hao-installer-*.iso` 启动后会自动进入全屏安装界面，无需先打开
终端。依次完成网络、机型、磁盘和登录密码设置后，安装器会自动执行 Disko 与
`nixos-install`，并在结束时显示重启页面。

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

# 首次使用 / 升级依赖后：生成或更新 flake.lock 并提交（保证可复现）
nix flake lock
git add flake.lock && git commit -m "chore: update flake.lock"

# 更新系统（先确认 /var/lib/hao-secrets/admin-password-hash 已安装）
sudo nixos-rebuild switch --flake .#HAO_DESKTOP

# 回滚到上一个版本
sudo nixos-rebuild switch --rollback

# 清理旧版本
sudo nix-collect-garbage --delete-older-than 7d
```

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
- 默认使用 Codex；运行 `ai-pick` 可临时选择 Codex、Claude Code 或 OpenCode。
- 运行 `hao-agent --set claude` 可修改默认 Agent，支持值为 `codex`、`claude`、`opencode`。

第一次使用某个 Agent 时，在终端完成它自己的登录：

```bash
codex login
claude # 首次启动时按提示登录
opencode auth login
```

登录凭据由各 CLI 保存在当前用户目录中，不会写入 Git 仓库或 Nix Store。Agent 仍保留正常的命令确认流程，不会默认获得免确认执行权限。
`admin` 同时被授权进行免密远程系统调试；该账户及其 SSH 密钥应按 root 权限保护。

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
