# 🖥️ NixOS 配置

**笔记本 + 台式机 + 虚拟机共用的 NixOS 配置。** 用 flake 管理，多台机器共享大部分设置（桌面、输入法、开发环境、游戏），每台机器只写自己特有的部分（硬件驱动、电源方案）。

> ⚠️ **使用前：** 复制 `vars/secrets.example.nix` 为 `vars/secrets.nix`，填入你的 EasyTier 密钥和 peer 地址。

| 主机 | 机型 | CPU | GPU | 显卡模式 |
|------|------|-----|-----|---------|
| **HAO_OFFLINE** | 神舟战神 Z7-KP7Z 笔记本 | i7-8750H (Coffee Lake) | GTX 1060 6GB | 按需调用（省电） |
| **HAO_DESKTOP** | 自组台式机 | i5-13600KF (Raptor Lake) | RTX 4070 Super 12GB | 独显常开（全性能） |
| **HAO_HYPERV** | Hyper-V Gen 2 虚拟机 | 宿主机 vCPU | 无（软件渲染） | 不适用 |

---

## 你是什么水平？

> **如果你第一次接触 NixOS**，建议先读一遍[入门指南](https://nixos.org/manual/nixos/stable/#sec-installation)了解基本概念，再回来按本说明装系统。

> **如果你用过 Linux 但没用过 NixOS**，下面这些名词先了解一下：
> - **Flake**：Nix 的模块化配置方式，类似 package.json 之于 npm。本仓库就是个 flake
> - **disko**：自动分区的工具，一条命令搞定磁盘布局
> - **nixos-install**：NixOS 的安装命令，从配置生成整个系统
> - **nixos-rebuild**：装好后日常更新系统的命令

---

## 安装前的准备

### 你需要的东西

- [x] **一台能上互联网的电脑** — 安装全程在线，大量包需要下载
- [x] **一个 8GB+ 的 U 盘** — 做 NixOS 安装盘
- [x] **一台目标机器** — 要装 NixOS 的电脑（台式机或笔记本）
- [x] **耐心** — 第一次构建会下载很多包，可能十几分钟

### 做安装盘

1. 下载 NixOS 镜像（选 **GNOME** 版本，有图形界面方便操作）
   - 国内镜像：https://mirrors.tuna.tsinghua.edu.cn/nixos-images/
   - 找最新 `nixos-gnome-*-x86_64-linux.iso`

2. 写入 U 盘（Windows 用 Rufus / balenaEtcher，Linux 用 dd）
   ```bash
   # Linux 下写入 U 盘（假设 U 盘是 /dev/sdb，确认别写错！）
   sudo dd if=下载的镜像.iso of=/dev/sdb bs=4M status=progress
   ```

3. U 盘插到目标机器，开机选 U 盘启动（通常是 F12 / F2 / Del 进 BIOS 改启动顺序）

### 启动后的第一步

进入 NixOS 安装环境（有桌面），打开终端（Terminal）。

先确认以下信息：

```bash
# 看磁盘叫什么名字 —— 后续所有命令里的 nvme0n1 要根据这个改
lsblk

# 看能不能上网（右上角网络图标或命令行）
ping -c 3 nixos.org
```

> **U 盘里的 NixOS 不是一个能用的系统**，它只是装系统的工具。你要用它来"刻"一个真正的系统到硬盘上。

> **NixOS ISO 默认不带 git**，如果后面要用 git clone 仓库，先装：
> ```bash
> nix-shell -p git
> ```

---

## 一、台式机 HAO_DESKTOP — 单系统（推荐）

**场景：整块硬盘只装 NixOS，没有 Windows。**

**特点：最快最简单，用 disko 自动分区，不到 5 分钟搞定。**

### 第一步：分区（一条命令）

```bash
sudo nix run github:accoutmissing/HAO_OFFLINE_NIX#disko -- --mode disko \
  https://raw.githubusercontent.com/accoutmissing/HAO_OFFLINE_NIX/main/hosts/HAO_DESKTOP/disko-config.nix
```

**这条命令干了什么：**
- 把整块盘（`/dev/nvme0n1`）擦掉重新分区
- 分一个 512MB 的 EFI 启动分区（label 叫 `BOOT`）
- 剩下的空间全给 NixOS（Btrfs 文件系统，label 叫 `NIXOS`）
- 自动创建 `@`（根目录）和 `@home`（家目录）两个子卷
- 自动挂载到 `/mnt`，省去手动 mount 的步骤

> ⚠️ **这条命令会清空整块硬盘的数据**。如果你硬盘上有重要文件，先备份。

**如果报错说设备不存在：**
```bash
# 先 lsblk 看你的硬盘实际叫什么，然后改 disko-config.nix 里的 device
# 常见名字：nvme0n1（NVMe 固态）、sda（SATA 固态/机械）、nvme1n1（第二个 NVMe 槽）
```

### 第二步：安装系统

```bash
sudo nixos-install --flake github:accoutmissing/HAO_OFFLINE_NIX#HAO_DESKTOP
```

**这条命令干了什么：**
- 根据我们仓库里的配置，生成完整的 NixOS 系统
- 装到 `/mnt`（上一步分区已经挂载好了）
- 提示你设 root 密码（记好，重启后要用）

**`#HAO_DESKTOP` 是什么意思？**
- flake 里有 HAO_DESKTOP（台式机）和 HAO_OFFLINE（笔记本）两套配置
- `#HAO_DESKTOP` 告诉 nixos-install 用台式机那套

### 第三步：重启

```bash
sudo reboot
```

拔掉 U 盘。如果能进图形界面，恭喜你，装好了。

---

## 二、台式机 HAO_DESKTOP — 双系统（Windows + NixOS）

**场景：已经有 Windows 了，想再装个 NixOS 双系统。**

> ⚠️ **双系统比单系统多几个步骤**，因为 disko 不能跳过 Windows 分区，需要手动分。

### 安装前的准备（在 Windows 里做）

1. **备份重要数据**（万一操作失误…）
2. **给 NixOS 腾空间**：Windows 磁盘管理 → 右键 C 盘 → 压缩卷 → 压缩出 **至少 500GB** 的未分配空间
3. **关闭 Windows 快速启动**：控制面板 → 电源选项 → 选择电源按钮功能 → 取消勾选"启用快速启动"

### 第一步：从 U 盘启动后，看分区情况

```bash
lsblk
# 你应该看到类似这样的输出：
# nvme0n1           — 整块盘
# ├─nvme0n1p1       — EFI 分区（FAT32，label 通常是 SYSTEM）
# ├─nvme0n1p2       — Windows（NTFS，装了 Windows）
# └─nvme0n1p3       — 空闲空间（刚刚压缩出来的，还没文件系统）
```

> **如果你完全看不懂 lsblk 的输出：** 上面是文字版，下面这个图帮你理解——`nvme0n1` 是整块 2TB 的 SSD，`nvme0n1p1/p2/p3` 是它上面的分区，就像把一个书柜分成几格。p3 就是你要用来装 NixOS 的那格。

### 第二步：在空闲空间创建 NixOS 分区

```bash
# 1. 看你的未分配空间是哪个 partition number
#    假设是 nvme0n1p3（以 lsblk 实际输出为准）
#    把下面所有 nvme0n1 和 p3 改成你实际的名字

# 2. 在空闲空间上创建分区
sudo parted /dev/nvme0n1 -- mkpart primary btrfs 50% 100%

# 3. 标记它不是 EFI 分区
sudo parted /dev/nvme0n1 -- set 3 esp off
```

> **`50% 100%` 是什么意思？** Windows 装在前 50% 的磁盘空间，NixOS 装在后 50%。如果你的盘是 2TB，那就是 Windows 占前 1TB，NixOS 占后 1TB。如果你的未分配空间在别的位置，需要调整这两个百分比。

### 第三步：格式化 + 创建子卷

```bash
# 格式化新分区为 Btrfs
sudo mkfs.btrfs -L NIXOS /dev/nvme0n1p3

# 挂载到 /mnt
sudo mount /dev/nvme0n1p3 /mnt

# 创建 Btrfs 子卷（类似"文件夹"但更高级，可以单独设置压缩和快照）
sudo btrfs subvolume create /mnt/@      # 根目录
sudo btrfs subvolume create /mnt/@home   # 家目录

# 卸载，下一步重新挂载子卷
sudo umount /mnt
```

> **为什么要搞子卷？** `@` 和 `@home` 分开，以后重装系统可以保留 `/home` 里的文件不丢。类似 Windows 把系统和用户数据分在 C 盘 D 盘。

### 第四步：挂载所有分区

```bash
# 挂载 @ 子卷到 /mnt（作为根目录）
sudo mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p3 /mnt

# 创建 boot 和 home 的挂载点
sudo mkdir -p /mnt/{boot,home}

# 挂载 EFI 分区（与 Windows 共用同一个 EFI 分区）
sudo mount /dev/nvme0n1p1 /mnt/boot

# 挂载 @home 子卷
sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home
```

### 第五步：安装系统

```bash
# 克隆仓库到安装目标
sudo git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git /mnt/etc/nixos

# 安装（用本地路径，因为 disk 方式可能因为双系统 EFI 分区 label 不同而失败）
sudo nixos-install --flake /mnt/etc/nixos#HAO_DESKTOP
```

> **为什么这里不用 `github:` 而是用本地路径？** 双系统的 EFI 分区 label 可能不是 `BOOT` 而是 `SYSTEM`。装好后需要根据实际 label 改一下硬件配置。

### 第六步：修复 /boot 路径（如果需要）

装完如果重启不进系统（grub 报错），说明 EFI 分区的 label 不对：

```bash
# 重启前，先记下 EFI 分区的实际 label
lsblk -o NAME,LABEL,PARTLABEL,UUID,FSTYPE
# 如果 nvme0n1p1 的 LABEL 不是 BOOT 而是 SYSTEM
# 安装完成后需要改 /mnt/etc/nixos/hosts/HAO_DESKTOP/hardware-configuration.nix
# 把 /boot 的 device 从 /dev/disk/by-label/BOOT 改成 /dev/nvme0n1p1
```

### 第七步：重启

```bash
sudo reboot
```

systemd-boot 会自动识别 Windows 启动项，开机菜单会显示两个系统，按方向键选你要进的系统。

---

## 三、笔记本 HAO_OFFLINE

**场景：单独一台笔记本，只装 NixOS。**

**特点：笔记本硬件型号多，磁盘用 UUID 识别（不是 label），安装多一步。**

### 第一步：分区

笔记本的分区方案和台式机类似，参考 `hosts/HAO_OFFLINE/disko-config.nix`。

手动分区（参考 hosts/HAO_OFFLINE/disko-config.nix 的布局）
```bash
# 假设硬盘是 /dev/nvme0n1
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart primary btrfs 512MB 100%

# 格式化
sudo mkfs.fat -F 32 /dev/nvme0n1p1
sudo mkfs.btrfs -L NIXOS /dev/nvme0n1p2

# 创建子卷 + 挂载（同上）
sudo mount /dev/nvme0n1p2 /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo umount /mnt
sudo mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/{boot,home}
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
```

### 第二步：生成硬件配置

```bash
sudo nixos-generate-config --root /mnt
```

**这条命令干了什么：**
- 扫描你电脑的硬件（磁盘、网卡、显卡等）
- 自动生成 `/mnt/etc/nixos/hardware-configuration.nix`
- 这个文件包含了磁盘的 UUID、内核模块等信息

> **为什么笔记本要单独生成硬件配置，台式机不用？** 台式机用磁盘 label（固定的名字如 NIXOS、BOOT）寻找分区，这个不会变。笔记本的磁盘 UUID 每台机器不同，没法提前写好带在仓库里。所以笔记本需要在安装时生成，台式机可以直接用仓库里写好的。

### 第三步：克隆仓库 + 复制硬件配置

```bash
# 克隆仓库
sudo git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git /mnt/etc/nixos

# 把刚刚生成的硬件配置复制到笔记本的 host 目录
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/HAO_OFFLINE/
```

> **为什么还要复制？** `nixos-generate-config` 生成的文件在 `/mnt/etc/nixos/` 下，但我们的仓库结构里硬件配置放在 `hosts/HAO_OFFLINE/` 下。需要复制过去，这样 `nixos-install` 才能找到它。

### 第四步：安装并重启

```bash
# 安装（用本地路径，因为硬件配置是刚生成的）
sudo nixos-install --flake /mnt/etc/nixos#HAO_OFFLINE

# 重启
sudo reboot
```

---

## 四、虚拟机 HAO_HYPERV

**场景：在 Windows Hyper-V 中测试配置，无需物理机。**

**特点：没有 GPU、不涉及游戏，主要用来验证模块语法和桌面组件能否正常加载。**

### 创建虚拟机（Windows 管理员 PowerShell）

```powershell
$vm = "NixOS-Test"
New-VM -Name $vm -Generation 2 -MemoryStartupBytes 4GB `
  -NewVHDPath "D:\VMs\$vm.vhdx" -NewVHDSizeBytes 30GB
Set-VM -Name $vm -ProcessorCount 4
Set-VMFirmware -VMName $vm -EnableSecureBoot Off
Connect-VMNetworkAdapter -VMName $vm -SwitchName "Default Switch"
```

### 虚拟机内安装

```bash
# 查看磁盘（VM 里通常是 /dev/sda）
lsblk

# 分区（UEFI + Btrfs）
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart root btrfs 512MiB 100%

sudo mkfs.fat -F 32 -n BOOT /dev/sda1
sudo mkfs.btrfs -L NIXOS /dev/sda2

sudo mount -o compress=zstd,noatime /dev/sda2 /mnt
sudo mkdir /mnt/boot
sudo mount /dev/sda1 /mnt/boot

# 生成硬件配置
sudo nixos-generate-config --root /mnt

# 装 git + 克隆仓库
nix-shell -p git --run "git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git /mnt/etc/nixos"

# 安装
sudo nixos-install --flake /mnt/etc/nixos#HAO_HYPERV

# 重启
sudo reboot
```

> **限制：** 无 GPU 加速、无增强会话模式。niri 用 llvmpipe 软件渲染，够验证配置语法正确，不适合测性能或游戏。

---

## 安装时常见问题

### ❌ "网络超时" / 下载特别慢

本配置已预设 TUNA/USTC 国内镜像缓存，正常不需要额外设置。如果仍有问题：

```bash
sudo nixos-install --flake /mnt/etc/nixos#HAO_DESKTOP \
  --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org"
```

### ❌ "找不到 /dev/nvme0n1"

你的硬盘名字不一样。先 `lsblk` 看看实际叫什么，然后：
- **用 disko 的**：把 `disko-config.nix` 里的 `/dev/nvme0n1` 改成实际名字
- **手动分区的**：把下面所有 `nvme0n1` 改成实际名字

常见名字对照表：
| 硬盘类型 | 常见名字 | 说明 |
|---------|---------|------|
| NVMe 固态 | `nvme0n1` | 最常见，插在 M.2 接口 |
| SATA 固态 | `sda` | 2.5 寸或 mSATA |
| 机械硬盘 | `sda` | SATA 接口 |
| SD 卡 / U 盘 | `sdb` / `sdc` | 一般不是用这个装系统 |
| 第二个 NVMe | `nvme1n1` | 如果有两个 M.2 插槽 |

### ❌ 安装过程卡在某一步很久

- 第一次 nixos-install 会下载大量包，**正常需要 10-30 分钟**
- 如果卡超过 30 分钟，按 `Ctrl+C` 重试，有时是网络问题
- 确保网络连接正常

### ❌ 装好后启动不进图形界面

```bash
# 启动时按 e 进入编辑模式，看看有没有报错
# 常见原因：显卡驱动没配置好
# 装好系统后先运行：
sudo nixos-rebuild switch --flake /etc/nixos#HAO_DESKTOP
```

### ❌ Hyper-V 虚拟机引导后黑屏

确认 `boot.blacklistedKernelModules = [ "hyperv_fb" ]` 已在配置中。Hyper-V 合成帧缓冲可能跟 Wayland 冲突。检查 VM 固件中安全启动已关闭。

---

## 装好系统之后

### 常用命令

```bash
# 语法检查（推荐每次改动后跑，秒级完成）
nix flake check

# 更新系统（拉到最新包 + 部署）
nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#HAO_DESKTOP

# 笔记本换成 HAO_OFFLINE，虚拟机换成 HAO_HYPERV

# 只构建不切换（测试能不能编译通过）
nixos-rebuild build --flake /etc/nixos#HAO_DESKTOP

# 回滚到上一个版本
sudo nixos-rebuild switch --flake .#HAO_DESKTOP --rollback

# 清理旧版本释放空间
sudo nix-collect-garbage --delete-older-than 7d
```

> **`/etc/nixos#` 和 `github:accoutmissing/HAO_OFFLINE_NIX#` 有什么区别？**
> - `/etc/nixos#`：用本地仓库（装好系统后，仓库在 `/etc/nixos`）
> - `github:...`：从 GitHub 远程拉（U 盘安装时用）

### 笔记本按需调用独显

```bash
# 跑游戏或需要独显的应用时：
nvidia-offload <你要运行的程序>
# 或者
prime-run <你要运行的程序>

# 验证是否在用独显
prime-run glxinfo | grep "OpenGL renderer"
```

### 台式机什么也不要做

RTX 4070 独显直出，默认就是全部用独显。

---

## 这个仓库的结构（给想改配置的人）

```
nixos/
├── flake.nix                        # 入口——定义用哪些包、怎么组合
├── hosts/
│   ├── HAO_OFFLINE/                 # 笔记本
│   │   ├── default.nix              # 主机名 + 开启哪些模块
│   │   ├── hardware-configuration.nix  ← .gitignore 排除，安装时生成
│   │   ├── optimus.nix              # 显卡驱动（GTX 1060）
│   │   └── disko-config.nix         # 分区方案参考
│   ├── HAO_DESKTOP/                 # 台式机
│   │   ├── default.nix              # 主机名 + 开启哪些模块
│   │   ├── hardware-configuration.nix  ← 跟踪在 git（因为用 label，不变）
│   │   ├── nvidia.nix               # 显卡驱动（RTX 4070）
│   │   ├── disko-config.nix         # 单系统分区方案
│   │   └── disko-config-dualboot.nix # 双系统参考
│   └── HAO_HYPERV/                  # 虚拟机
│       └── default.nix              # 主机名 + 关闭 GPU/游戏
├── modules/
│   ├── nixos/
│   │   ├── base/                    # 系统基础（引导、SSH、用户、语言）
│   │   └── desktop/                 # 桌面环境（窗口管理器、输入法、音频、游戏）
│   ├── home/linux/                  # 用户级配置（Zsh、Git、Starship）
│   ├── lib/                         # 工具函数
│   └── vars/                        # 用户名、SSH 公钥、缓存配置
├── vars/
│   ├── default.nix                  # 公共变量（用户名、缓存、密钥引用）
│   └── secrets.example.nix          # → 复制为 secrets.nix 填入密钥
└── .gitignore
```

### 你可以改什么

- **想加个软件**：改 `modules/nixos/base/` 或 `modules/nixos/desktop/` 下的 nix 文件
- **想调整键盘布局/输入法**：改 `modules/nixos/desktop/`
- **想改桌面壁纸/主题**：取决于你用的桌面壳层 Noctalia 的设置
- **想给某台机器开某个功能**：改对应 `hosts/<hostname>/default.nix`，把 `enable = true` 加上

---

## 参考

| 资源 | 用途 |
|------|------|
| [NixOS 入门指南](https://nixos.org/manual/nixos/stable/#sec-installation) | 官方安装手册，最权威 |
| [nixos-and-flakes-book](https://github.com/ryan4yin/nixos-and-flakes-book) | 中文 Flakes 入门书，解释 flake、module 概念 |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | 本项目架构参考 |
| [NixOS Manual](https://nixos.org/manual/nixos/stable/) | 全部官方文档 |
| [Noctalia](https://noctalia.dev) | 桌面壳层 |
| [Hermes Agent](https://hermes-agent.nousresearch.com/) | 远程管理（写这个文档的 AI） |
| [ProtonDB](https://www.protondb.com/) | 查你买的游戏能不能在 Linux 跑 |

---

> 💡 **一句话记住安装思路：** 分区 → 生成硬件配置（笔记本需要）→ 克隆仓库 → nixos-install。所有问题都可以 `lsblk` + 看日志解决。
