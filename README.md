# 🖥️ NixOS 配置 · 三主机

**笔记本 + 台式机 + 虚拟机共用的 NixOS flake 配置**。

> ⚠️ 使用前：复制 `vars/secrets.example.nix` 为 `vars/secrets.nix`，填入你的 EasyTier 密钥和 peer 地址。

| 主机 | 机型 | CPU | GPU | NVIDIA 模式 |
|------|------|-----|-----|-------------|
| **HAO_OFFLINE** | 神舟战神 Z7-KP7Z 笔记本 | Intel i7-8750H (Coffee Lake) | GTX 1060 6GB | Optimus PRIME Offload（省电） |
| **HAO_DESKTOP** | 自组台式机 | Intel i5-13600KF (Raptor Lake) | RTX 4070 Super 12GB | 独显直出（全时性能） |
| **HAO_HYPERV** | Hyper-V Gen 2 虚拟机 | 宿主机 vCPU | 无（软件渲染） | 不适用 |

底层参考 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)，Nix 语言入门看 [nixos-and-flakes-book](https://github.com/ryan4yin/nixos-and-flakes-book)。

---

## 目录

- [架构概览](#架构概览)
- [包含什么](#包含什么)
- [从零安装](#从零安装)
  - [台式机 HAO_DESKTOP（两步安装）](#台式机-hao_desktop两步安装)
  - [笔记本 HAO_OFFLINE](#笔记本-hao_offline)
  - [虚拟机 HAO_HYPERV](#虚拟机-hao_hyperv)
- [日常运维](#日常运维)
- [仓库结构](#仓库结构)
- [新增主机](#新增主机)
- [常见问题](#常见问题)
- [参考资源](#参考资源)

---

## 架构概览

### 模块组织

| 层 | 职责 | 内容 |
|---|---|---|
| **base/** | 与桌面无关的系统基础 | boot、nix、ssh、用户、语言、zram |
| **desktop/** | 图形界面 | Niri、Noctalia、Fcitx5、PipeWire、蓝牙、打印、游戏 |
| **hosts/<hostname>/** | 该机器特有 | 硬件驱动、NVIDIA 配置、电源方案 |
| **home/linux/** | 用户级（Home Manager） | Git、Zsh、Starship |

### mkSystem 工厂模式

`flake.nix` 通过 `mkSystem` 函数生成各主机配置，共享模块抽离为 `baseModules`：

```nix
baseModules = [
  ./modules/nixos/base      # 系统基础
  ./modules/nixos/desktop   # 桌面环境
  disko.nixosModules.default
  home-manager.nixosModules.home-manager
];

mkSystem = hostname: extraModules:
  lib.nixosSystem {
    modules = baseModules ++ [
      ./hosts/${hostname}
      { home-manager.users.${myvars.username} = import ./home/linux; }
    ];
  };

nixosConfigurations = {
  HAO_OFFLINE = mkSystem "HAO_OFFLINE" [ ];
  HAO_DESKTOP = mkSystem "HAO_DESKTOP" [ ];
  HAO_HYPERV = mkSystem "HAO_HYPERV" [ ];
};
```

部署时用 `#` 指定主机（系统安装后仓库在本地 `/etc/nixos`）：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#HAO_DESKTOP
sudo nixos-rebuild switch --flake /etc/nixos#HAO_OFFLINE
```

### 硬件配置策略

| 策略 | 笔记本 HAO_OFFLINE | 台式机 HAO_DESKTOP | 虚拟机 HAO_HYPERV |
|---|---|---|---|
| 跟踪在 git | ❌（UUID 多变，`.gitignore` 排除） | ✅（`by-label` 确定性路径） | ❌（安装时生成） |
| 安装方式 | 安装时 `nixos-generate-config` 生成 | disko 分区时创建固定 label | 手动分区 + generate-config |
| NVIDIA 模式 | PRIME Offload（省电，按需调用独显） | 直出（独显常开） | 无（软件渲染 llvmpipe） |
| 电源管理 | `thermald` + `TLP`（电池优化） | `power-profiles-daemon` | 无 |
| 驱动版本 | `open = false`（GTX 1060 Pascal 不支持） | `open = true`（RTX 4070 Ada Lovelace 支持） | modesetting |

---

## 包含什么

| 类别 | 内容 |
|---|---|
| 🔲 **窗口管理器** | Niri（平铺式 Wayland 25.02+） |
| ⌨️ **输入法** | Fcitx5 + Rime（小鹤双拼） |
| 🌐 **代理** | mihomo + Clash Verge Rev |
| 🖥️ **桌面壳层** | Noctalia（bar、dock、通知中心、锁屏、启动器） |
| 🖥️ **终端** | Kitty + Starship + Zsh |
| 🎨 **设计工具** | GIMP, Inkscape, Krita, Blender, Font Manager |
| 🛠️ **开发环境** | Node.js, Python, Git + delta + lazygit, Podman, libvirtd, pnpm, yarn |
| 🐳 **容器** | Podman（兼容 Docker CLI） + virt-manager |
| 💬 **通信** | WeChat, QQ（Flatpak） |
| 🔗 **远程管理** | SSH + EasyTier P2P → 云端 Hermes 接管 |
| 🌍 **VPN** | EasyTier（开机自动连接 VPS） |
| 🎮 **游戏** | Steam + Proton + GameMode + MangoHud + Lutris + Moonlight |
| 🔊 **音频** | PipeWire + WirePlumber + 低延迟模式（游戏优化） |
| 🖨️ **打印** | CUPS |
| 📡 **蓝牙** | BlueZ + Blueman |

---

## 从零安装

> **ISO 安装环境**可直接 `git clone https://github.com/accoutmissing/nixos.git`。
> 如果克隆时遇到网络问题，用 U 盘搬运仓库到 `/mnt/etc/nixos` 然后本地路径安装。

### 台式机 HAO_DESKTOP — 单系统（两步安装）

```bash
# 用本地路径替代 github:accoutmissing/nixos（假设仓库在 /mnt/etc/nixos）
sudo nix --extra-experimental-features 'nix-command flakes' run \
  /mnt/etc/nixos#disko -- --mode disko \
  /mnt/etc/nixos/hosts/HAO_DESKTOP/disko-config.nix
sudo nixos-install --flake /mnt/etc/nixos#HAO_DESKTOP
```

### 台式机 HAO_DESKTOP — 双系统（Windows + NixOS）

> 用不了 disko（无法跳过已有 Windows 分区），需手动分区。

```bash
# 1. 先装 Windows（留 ~500GB+ 未分配空间给 NixOS）

# 2. 从 NixOS U 盘启动后，查看分区
lsblk
# 预期：p1=EFI, p2=Windows(NTFS), 剩余未分配

# 3. 在未分配空间创建 NixOS 分区
#    假设 nvme0n1p3 是空闲的（以 lsblk 实际输出为准）
sudo parted /dev/nvme0n1 -- mkpart primary btrfs 50% 100%
sudo parted /dev/nvme0n1 -- set 3 esp off  # 不是 EFI 分区

# 4. 格式化为 Btrfs + 创建子卷
sudo mkfs.btrfs -L NIXOS /dev/nvme0n1p3
sudo mount /dev/nvme0n1p3 /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo umount /mnt

# 5. 挂载所有分区
sudo mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p3 /mnt
sudo mkdir /mnt/{boot,home}
sudo mount /dev/nvme0n1p1 /mnt/boot         # EFI（与 Windows 共享）
sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home

# 6. 生成硬件配置 + 修改 /boot 路径
sudo nixos-generate-config --root /mnt
# 检查 /mnt/etc/nixos/hardware-configuration.nix 中 /boot 的 device
# 如果用的是 EFI 分区（通常是 /dev/nvme0n1p1），后续部署时参考

# 7. clone + 安装（私密仓库用 PAT 或 USB 搬运，见上方说明）
sudo git clone https://github.com/accoutmissing/nixos.git /mnt/etc/nixos
sudo nixos-install --flake /mnt/etc/nixos#HAO_DESKTOP
```

> **注意：** 双系统下 EFI 分区由 Windows 创建，label 通常是 `SYSTEM` 而非 `BOOT`。
> 首次部署后需用 `lsblk` 确认实际 label，更新 `hardware-configuration.nix` 中的 `/boot` device 路径。
> systemd-boot 会自动检测 Windows 启动项，开机菜单会显示两个系统选项。

### 笔记本 HAO_OFFLINE

笔记本硬件配置用 UUID（`nixos-generate-config` 生成），需要额外一步复制。

```bash
# 1. 分区（参考 hosts/HAO_OFFLINE/disko-config.nix 的布局手动分）

# 2. 生成硬件配置
sudo nixos-generate-config --root /mnt

# 3. clone 仓库 + 复制硬件配置
sudo git clone https://github.com/accoutmissing/nixos.git /mnt/etc/nixos
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/HAO_OFFLINE/

# 4. 从本地路径安装
sudo nixos-install --flake /mnt/etc/nixos#HAO_OFFLINE
```

### 虚拟机 HAO_HYPERV

在 Windows Hyper-V 中测试配置，无需 GPU。

**创建 VM（管理员 PowerShell）：**

```powershell
$vm = "NixOS-Test"
New-VM -Name $vm -Generation 2 -MemoryStartupBytes 4GB `
  -NewVHDPath "D:\VMs\$vm.vhdx" -NewVHDSizeBytes 30GB
Set-VM -Name $vm -ProcessorCount 4
Set-VMFirmware -VMName $vm -EnableSecureBoot Off
Connect-VMNetworkAdapter -VMName $vm -SwitchName "Default Switch"
```

**VM 内安装：**

```bash
# 查看磁盘（通常 /dev/sda）
lsblk

# 分区（UEFI + Btrfs，不走 disko）
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart root btrfs 512MiB 100%

sudo mkfs.fat -F 32 -n BOOT /dev/sda1
sudo mkfs.btrfs -L NIXOS /dev/sda2

sudo mount -o compress=zstd,noatime /dev/sda2 /mnt
sudo mkdir /mnt/boot
sudo mount /dev/sda1 /mnt/boot

# 生成硬件配置 + clone + 安装
sudo nixos-generate-config --root /mnt
sudo git clone https://github.com/accoutmissing/nixos.git /mnt/etc/nixos
sudo nixos-install --flake /mnt/etc/nixos#HAO_HYPERV
```

> **限制：** 无 GPU 加速、无增强会话模式。niri 用 llvmpipe 软件渲染，够验证模块语法和桌面组件加载，不适合测性能或游戏。

---
## 日常运维

```bash
# 语法检查（推荐每次改动后跑，秒级完成）
nix flake check

# 更新版本锁 + 部署（一步到位）
nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#HAO_DESKTOP
# 笔记本换成 HAO_OFFLINE，虚拟机换成 HAO_HYPERV

# 仅构建验证（不切换）
nixos-rebuild build --flake /etc/nixos#HAO_DESKTOP

# 回滚
sudo nixos-rebuild switch --flake /etc/nixos#HAO_DESKTOP --rollback

# 清理旧版本
sudo nix-collect-garbage --delete-older-than 7d
```

---

## 仓库结构

```
nixos/
├── flake.nix                        # 入口：mkSystem 工厂 + inputs
├── hosts/
│   ├── HAO_OFFLINE/                 # 笔记本
│   │   ├── default.nix              # 主机名 + CPU + 模块开关（pathExists 条件导入）
│   │   ├── hardware-configuration.nix  ← .gitignore 排除（安装时生成）
│   │   ├── optimus.nix              # GTX 1060 PRIME Offload
│   │   └── disko-config.nix         # 分区模板（参考）
│   └── HAO_DESKTOP/                 # 台式机
│       ├── default.nix              # 主机名 + CPU + 模块开关
│       ├── hardware-configuration.nix  ← 跟踪在 git（by-label）
│       ├── nvidia.nix               # RTX 4070 Super 直出（无 Optimus）
│       ├── disko-config.nix         # 分区方案（单系统安装时用）
│       └── disko-config-dualboot.nix # 双系统分区参考（Windows + NixOS）
│   └── HAO_HYPERV/                  # Hyper-V 虚拟机
│       └── default.nix              # 主机名 + 模块开关（无 GPU/游戏）
├── modules/
│   ├── nixos/
│   │   ├── base/                    # boot、nix(含缓存)、ssh、用户、i18n、zram
│   │   └── desktop/                 # Niri、Noctalia、输入法、音频、游戏、远程管理
│   ├── home/linux/                  # Home Manager（Git、Zsh、Starship）
│   ├── lib/                         # scanPaths 工具函数
│   └── vars/                        # 用户名、hostname、SSH 公钥
└── .gitignore                       # 排除 secrets 和 HAO_OFFLINE 硬件配置
```

---

## 新增主机

1. 在 `hosts/` 下建主机目录 `hosts/<HOSTNAME>/`
2. 创建 `default.nix`（主机名 + CPU + 模块开关）
3. 创建硬件配置：
   - **by-label 模式**（推荐）：写 `disko-config.nix` + `hardware-configuration.nix`，跟踪在 git
   - **UUID 模式**：`hardware-configuration.nix` 放 `.gitignore`，安装时生成
4. 有独显就加对应配置（Intel+NVIDIA → `optimus.nix` / 台式直出 → `nvidia.nix`）
5. 在 `flake.nix` 的 `nixosConfigurations` 中加一行：`HOSTNAME = mkSystem "HOSTNAME" [ ];`

可选模块（通过 mkIf 控制，在 `default.nix` 中 `enable = true`）：
- `modules.desktop.gaming.enable` — Steam + Lutris + GameMode + Moonlight
- `modules.desktop.hermes-access.enable` — SSH + EasyTier + 免密 sudo
- `modules.desktop.noctalia.enable` — Noctalia 桌面壳层

---

## 常见问题

### 1. 安装时网络超时

本配置已预设 TUNA/USTC 国内镜像缓存，正常不需要额外设置。若仍有问题：

```bash
sudo nixos-install --flake /mnt/etc/nixos#HAO_DESKTOP \
  --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org"
```

### 2. 构建时大量本地编译（慢）

检查 `nix.settings.substituters` 是否配置正确。本配置已预设 TUNA/USTC 镜像、nix-community、nix-gaming、noctalia 缓存。

### 3. NVIDIA 不工作

**台式机（RTX 4070）：** 确认显示器插在显卡上，不要插主板。

**笔记本（GTX 1060 Optimus）：**
```bash
# 确认 Bus ID
lspci | grep -E "VGA|3D|Display"

# 按需调用独显
nvidia-offload <程序>
prime-run <程序>

# 测试
prime-run glxinfo | grep "OpenGL renderer"
```

### 4. 中文字体方块

```bash
fc-cache -fv
fc-match sans-serif
```

### 5. 磁盘空间不足

```bash
sudo nix-collect-garbage --delete-older-than 7d
```

### 6. Hyper-V 虚拟机引导后黑屏

确认 `boot.blacklistedKernelModules = [ "hyperv_fb" ]` 已配置。Hyper-V 合成帧缓冲与 Wayland 可能冲突。另检查 VM 固件中安全启动已关闭。

---

## 参考资源

| 资源 | 说明 |
|---|---|
| [ryan4yin/nixos-and-flakes-book](https://github.com/ryan4yin/nixos-and-flakes-book) | Flakes 入门书 |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | 本项目架构参考 |
| [NixOS Manual](https://nixos.org/manual/nixos/stable/) | 官方手册 |
| [Noctalia](https://noctalia.dev) | 桌面壳层 |
| [Hermes Agent](https://hermes-agent.nousresearch.com/) | 远程管理 |
| [EasyTier](https://github.com/EasyTier/EasyTier) | P2P 组网 |
| [ProtonDB](https://www.protondb.com/) | 游戏兼容性查询 |
