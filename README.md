# 🖥️ HAO NixOS 配置

一套 **Flake + Home Manager** 管理的 NixOS 配置，覆盖 **笔记本 + 台式机 + 虚拟机 + 服务器** 四种场景，多台设备共享一套配置，各自只写硬件差异。

## ✨ 配置特点

| 类别 | 内容 |
|------|------|
| 🖥️ 主机 | HAO_OFFLINE（笔记本 i7-8750H + GTX 1060）/ HAO_DESKTOP（台式机 i5-13600KF + RTX 4070S）/ HAO_HYPERV（虚拟机）/ HAO_SERVER（服务器，独立分支） |
| 🪟 桌面 | Niri（滚动平铺 Wayland）+ Noctalia 壳层（bar/dock/启动器/锁屏）+ ReGreet 图形登录 |
| 🔤 中文输入 | Fcitx5 + Rime |
| 🎨 设计 | GIMP / Inkscape / Krita / Blender 全套 |
| 🛠️ 开发 | Node.js / Python / pnpm / lazygit / Starship 提示符 |
| 🎮 游戏 | Steam + Lutris + GameMode + MangoHud + Gamescope |
| 💬 通讯 | QQ / 微信（Linux 原生） |
| 🖥️ Windows 应用 | WinBoat 容器化 Windows VM（可选模块，仅台式机） |
| 🌐 网络 | EasyTier P2P 组网 + Clash Verge 代理 |
| 🐳 容器 | Podman（docker 兼容）+ libvirtd KVM |
| 🔒 安全 | SSH 禁密码 + root 锁定 + 密码 null assertion + secrets gitignored |
| 🔄 系统 | Btrfs + zstd 压缩 + zram + 每周自动 GC |
| 🇨🇳 国内优化 | 清华/中科大镜像 + 超时优化 |
| 🔧 CI | GitHub Actions `nix flake check` + 三主机 eval |
=======

## 🖥️ 主机一览

| 主机 | 机型 | 分支 | 说明 |
|------|------|------|------|
| **HAO_OFFLINE** | 神舟战神 Z7-KP7Z | main | i7-8750H + GTX 1060，Optimus 按需调用 |
| **HAO_DESKTOP** | 自组台式机 | main | i5-13600KF + RTX 4070S，独显常开 |
| **HAO_HYPERV** | Hyper-V Gen 2 | main | 虚拟机，无 GPU，验证桌面壳层 |
| **HAO_WSL** | Windows WSL2 | main | 无引导/无桌面精简配置，快速验证 flake |
| **HAO_SERVER** | 家庭服务器 / VPS | **HAO_SERVER** | 无头服务器，fail2ban + 容器 + 自动更新 |

## 🚀 快速开始

- 🐣 **第一次接触 Linux？** → [📖 安装入门指南（写给纯小白）](./INSTALL_GUIDE.md)
- ⚙️ **想按已有教程装系统？** → 参考 [README 旧版安装说明](https://github.com/accoutmissing/HAO_OFFLINE_NIX/blob/main/README.md)（已迁移至 INSTALL_GUIDE）
- 📦 **想用发布版本？** → [Releases](https://github.com/accoutmissing/HAO_OFFLINE_NIX/releases)

## 🛠️ 常用操作

```bash
# 查看仓库定义
nix flake show

# 验证配置能解析
nix flake check

# 首次使用 / 升级依赖后：生成或更新 flake.lock 并提交（保证可复现）
nix flake lock
git add flake.lock && git commit -m "chore: update flake.lock"

# 更新系统（拉到最新 + 部署）
sudo nixos-rebuild switch --flake .#

# 回滚到上一个版本
sudo nixos-rebuild switch --rollback

# 清理旧版本
sudo nix-collect-garbage --delete-older-than 7d
```

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
