# HAO NixOS 安装指南

推荐使用 HAO 镜像的安装向导，无需先输入安装命令。先备份要保留的文件；自动安装会清空你选择的整块硬盘。

## 推荐：五步完成安装

1. 在 [Releases](https://github.com/accoutmissing/HAO_OFFLINE_NIX/releases) 下载 HAO 镜像和对应校验文件。国内安装优先选匹配机型的离线版；没有离线版时用普通联网版。
2. 用 [Rufus](https://rufus.ie/zh/) 写入 U 盘。选择 ISO，点“开始”，如询问写入模式，选择 **DD 模式**，保留镜像的分区和引导信息。
3. 从启动菜单选择 **UEFI: 你的 U 盘**。本项目镜像暂未配置 Secure Boot 签名，需要先关闭安全启动。
4. 在向导里确认机型、选择硬盘、设置 `admin` 的登录密码。输入 `ERASE 磁盘名` 作最终确认，例如 `ERASE nvme0n1`。
5. 等待“安装完成”，重启时拔出 U 盘。使用 `admin` 和刚设置的密码登录。

| 镜像 | 对应设备 | 安装时是否需要下载 |
|------|----------|--------------------|
| 名称带 `offline-HAO_DESKTOP` | i5-13600KF + RTX 4070 Super 台式机 | 系统随镜像提供，无需联网下载 |
| 名称带 `offline-HAO_OFFLINE` | i7-8750H + GTX 1060 笔记本 | 系统随镜像提供，无需联网下载 |
| 名称不带 `offline` | 上述两种机型，向导内选择 | 需要联网下载系统软件 |

其他硬件不要盲选这两个配置，尤其是显卡与混合显卡设置。目标硬盘至少 64 GiB，日用建议 200 GB 以上；联网版 U 盘至少 8 GB，离线版建议 32 GB 以上，以实际镜像大小为准。

本分支新增了中文界面和离线镜像构建。已发布的 v1.2.7 是英文联网版，仍按其菜单配置网络；新功能需使用更新后的构建产物。若显卡无法启动中文窗口，新版会自动退回英文文字界面，步骤相同。

**下载新版候选镜像**：登录 GitHub，打开[离线版构建列表](https://github.com/accoutmissing/HAO_OFFLINE_NIX/actions/workflows/build-offline-installer.yml)或[联网版构建列表](https://github.com/accoutmissing/HAO_OFFLINE_NIX/actions/workflows/build-installer-iso.yml)，选择绿色成功的记录，在页面底部的 **Artifacts** 下载对应机型的压缩包并解压。`desktop` 是台式机，`laptop` 是笔记本。离线候选文件保留 14 天；正式发布后优先使用 Release 附件。

### 离线镜像是多个分卷时

[GitHub 单个 Release 附件须小于 2 GiB](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas)，因此大镜像会分为 `.iso.part00`、`.iso.part01` 等文件。

把对应机型的 **所有分卷、`SHA256SUMS-offline-*`、`Join-Installer.ps1` 和 `Join-Installer.cmd`** 下载到同一个文件夹，然后双击 `Join-Installer.cmd`。它会按顺序合并并校验完整 ISO；完成后用 Rufus 写入这个 ISO。电脑需留有能同时容纳分卷和合并后 ISO 的空间。

若只有一个 ISO，可在 Windows PowerShell 中核对：

```powershell
Get-FileHash .\hao-installer-实际文件名.iso -Algorithm SHA256
```

将结果与下载的校验文件对比。镜像仍从 GitHub 下载；可在网络方便的电脑下载后，用 U 盘或局域网传到安装电脑，离线版的安装现场无需再访问 GitHub。

### 联网版：自动选国内缓存，失败时再调整

先插网线。新版向导会自动检测清华、中科大和官方缓存，优先使用可达的国内源，并保留可达的后备源；检测通过后直接继续，无需逐项手动检查 GitHub。镜像已携带锁定的 Flake 源码，但联网版的软件仍需下载；未命中缓存的包还可能访问上游或本地构建。

检测不通过时，任选一种：

- 选择“连接 Wi-Fi”，也可连接手机热点，再检查下载源。
- 另一台电脑已有代理：在对方开启局域网访问，选择“使用局域网设备的代理”，填写类似 `http://192.168.1.10:7890` 的地址。
- 导入配置：通过 LocalSend 接收 **Mihomo 兼容、包含离线可用节点的 YAML**，再选择“导入代理配置并启用”。新版会预填最近收到的 YAML 路径，并读取配置里的 HTTP/mixed 端口。只有订阅网址、首次启动还需拉取节点的配置不适合引导联网。

LocalSend 和 Mihomo 已预装。使用 LocalSend 的两台设备须在同一局域网且能互访；发现不了对方时，可从 U 盘导入文件。临时代理同时用于安装器和 Nix 下载服务，仅在此次安装环境中生效，不会自动带入新系统。

### 遇到问题怎么办

- **下载或构建失败**：选择“调整网络后重试”或“重试当前步骤”。准备系统失败时不会清盘；清盘后的安装失败也只重试安装，不重新分区。
- **联网版提示临时空间不足**：换用匹配机型的离线镜像，避免把完整系统先构建到安装环境的内存盘。
- **需要保留 Windows**：不要使用自动整盘向导，阅读下面的高级双系统流程。
- **查看报错**：选择“查看安装日志”。也可按 `Ctrl+Alt+F2` 打开维修终端；安装完成后的日志位于 `/var/log/hao-install.log`。

登录密码明文不会写入磁盘，yescrypt 哈希保存在目标系统的 root-only 目录。向导中保存的 Wi-Fi 连接会带入新系统，其凭据仅保存在本机私有文件；无需首次开机再输一遍。系统配置保存在可编辑的 `/etc/nixos`。

## 以下为高级手动安装

仅在使用官方安装盘、保留 Windows 双系统，或需要修改硬件配置时继续阅读。普通 HAO 整盘安装使用上面的五步即可。


---

## 二、安装前你要准备什么

### 硬件清单

| 东西 | 说明 |
|------|------|
| 💻 一台要装 NixOS 的电脑 | 台式机或笔记本都行 |
| 💾 一个 **8GB 以上**的 U 盘 | 会被清空，先备份里面重要文件 |
| 🌐 能上网的网络 | 安装全程在线，最好插网线 |

### 下载两个东西

**1. 系统镜像（ISO 文件）**

优先使用 Release 中的 `hao-installer-*.iso`。如果 Release 暂时没有 HAO 镜像，
再下载 NixOS 官方 graphical 安装盘并使用后面的手动流程：

- 打开浏览器，访问：**https://mirrors.tuna.tsinghua.edu.cn/nixos-images/**
- 往下翻，找到最新日期那个文件夹，点进去
- 下载文件名里带 **`graphical`** 和 **`x86_64-linux`** 的 `.iso` 文件（25.05 起统一为 graphical）
  - 例如：`latest-nixos-graphical-x86_64-linux.iso`
- graphical 版本带完整桌面环境，对新手友好

**2. U 盘写入工具**

下载 **Rufus**（免费，无需安装）：

- 打开：**https://rufus.ie/zh/**
- 点下载按钮，得到一个 `rufus-x.x.exe` 文件

### 把镜像写入 U 盘

1. 插上 U 盘
2. 双击打开刚才下载的 `rufus-x.x.exe`
3. 界面上：
   - 「设备」选你的 U 盘（一般自动选中）
   - 点「选择」按钮，找到你下载的 `.iso` 文件
   - 其他选项**全部保持默认**，不用改
4. 点底部「开始」按钮
5. 如询问写入模式，选择「以 DD 镜像模式写入」，确定
6. 等进度条跑完（大约 3-5 分钟），U 盘就做好了

> ⚠️ 这一步会清空 U 盘里所有文件，确认没有重要东西再点开始。

---

## 三、从 U 盘启动电脑

NixOS U 盘做好了，现在要让电脑从 U 盘启动，而不是从硬盘里的 Windows 启动。

### 怎么进启动菜单

关机 → 插上 U 盘 → 开机 → **立刻、反复、快速按** 以下按键中的一个（不同品牌不同）：

| 品牌 | 进启动菜单的键 | 进 BIOS 设置的键 |
|------|---------------|-----------------|
| 华硕 (ASUS) | **F8** | F2 / Del |
| 联想 (Lenovo) | **F12** | F2 |
| 戴尔 (Dell) | **F12** | F2 |
| 惠普 (HP) | **F9** | F10 |
| 宏碁 (Acer) | **F12** | F2 |
| 神舟 (Hasee) | **F12** | F2 / Del |
| 微星 (MSI) | **F11** | Del |
| 技嘉 (Gigabyte) | **F12** | Del |

> 💡 **技巧**：不确定按哪个键？开机看到品牌 logo 的时候，屏幕底部或者角落通常会有一行小字告诉你（比如 "Press F12 for Boot Menu"）。

### 选择 U 盘启动

按对键后会出现一个蓝色或黑色的菜单，用方向键上下移动，选择你的 U 盘（名字里通常有 "USB" 或 U 盘的品牌名，比如 "SanDisk"、"Kingston"），然后按 **回车**。

出现 NixOS 启动画面后，选第一个选项（通常已经高亮了），直接按回车。

等十几秒，你会看到一个桌面——**这就是 NixOS 的安装环境**，现在可以开始装了。

---

## 四、进入安装环境后——第一步做什么

### 连上网络

安装全程需要联网下载。如果插了网线，一般自动就连上了。

如果用 WiFi：
- 点击桌面右上角的网络图标
- 选择你的 WiFi → 输入密码 → 连接
- 或者打开终端（桌面左下角找「终端」或「Terminal」图标），输入：
  ```
  nmtui
  ```
  会出来一个文字界面，用方向键操作，选 "Activate a connection" → 选你的 WiFi → 输入密码。

验证网络通了没有：
- 打开终端，输入 `ping -c 3 nixos.org` 然后回车
- 如果看到类似 `64 bytes from ...` 的回复，说明网络 OK

### 打开终端

**终端**（Terminal）就是一个黑底白字的窗口，你在里面打字指挥电脑干活。

- 桌面左下角找「终端」图标，点开
- 或者右键桌面空白处 → 选「打开终端」
- 后面所有命令都在终端里输入

> 💡 **小提示**：终端里 `Ctrl+C` 不是复制（复制是 `Ctrl+Shift+C`），`Ctrl+C` 是"停下来"的意思。粘贴是 `Ctrl+Shift+V`。如果命令跑到一半你想停，按 `Ctrl+C`。

---

## 五、开始安装

> 下面开始真正装系统了。**每条命令一行一行输，输完按回车。**

### 第 1 步：看看你的硬盘叫什么名字

```bash
lsblk
```

会输出类似这样的东西：

```
NAME        SIZE TYPE
nvme0n1    512G  disk     ← 这是你的硬盘
sda        14.8G disk     ← 这是你的 U 盘
```

你要记住硬盘的名字，一般是 `nvme0n1`（NVMe 固态）或 `sda`（SATA 固态/机械硬盘）。

> 🔴 **非常重要**：后面所有命令里的 `nvme0n1` 都要换成你实际看到的硬盘名字！如果看到的是 `sda`，就把所有 `nvme0n1` 换成 `sda`。

---

### 第 2 步：选择安装方案

根据你的情况，选下面 **A 或 B** 其中一个：

| 方案 | 适合谁 |
|------|--------|
| **A. 单系统**（整块盘只装 NixOS） | 电脑上**没有**需要保留的系统 / 旧电脑 / 不打算双系统 |
| **B. 双系统**（保留 Windows） | 电脑上已经有 Windows，想两个系统共存 |

---

### 🅰️ 方案 A：单系统（推荐新手用这个，最简单）


> ⚠️ **国内网络注意**：以下命令需要从 GitHub 下载，国内可能连不上或很慢。
> 如果 `git clone` 报错 `Failed to connect` 或一直卡住，先试试下面任意一种方法：
> 
> **方法 1：用浏览器下载 ZIP（最简单）**
> 在安装环境里打开 Firefox 浏览器，访问：
> `https://github.com/accoutmissing/HAO_OFFLINE_NIX/archive/refs/heads/main.zip`
> 下载完成后，在终端里解压：
> ```bash
> cd ~/Downloads
> unzip main.zip
> cd HAO_OFFLINE_NIX-main
> ```
> 
> **方法 2：开代理**
> 如果你有代理软件（Clash/V2Ray），先在安装环境里配置好代理：
> ```bash
> export https_proxy=http://127.0.0.1:7890
> ```
> 把 `7890` 换成你代理的端口号，然后再执行 `git clone`。
> 
> **方法 3：手机热点**
> 有时候手机开热点比 WiFi/宽带更容易连上 GitHub，不妨试试。
#### A-1：下载本仓库


```bash
nix-shell -p git
git clone --branch main https://github.com/accoutmissing/HAO_OFFLINE_NIX.git
cd HAO_OFFLINE_NIX
```

#### A-2：设置你的登录密码

装好系统后，你需要一个密码才能登录桌面。现在就设好。

先创建不会被 Git 跟踪的本地密钥暂存目录：

```bash
bash scripts/setup.sh
```

脚本会创建 `secrets/admin-password-hash` 和 `secrets/easytier.env`。这些文件只用于暂存，整个 `secrets/` 目录都不会上传到 GitHub。

然后生成密码哈希：

```bash
mkpasswd -m yescrypt > secrets/admin-password-hash
```

- 输入你想要的密码（**输入时屏幕不会显示任何东西，这是正常的**）
- 输入完成后，生成的 `$y$...` 哈希会直接写入本地暂存文件。
- 如需启用 EasyTier，再编辑环境文件：

```bash
nano secrets/easytier.env
```

把 `ET_NETWORK_SECRET=CHANGE_ME` 换成真实密钥；多个 peer 填入 `ET_PEERS=`，用英文逗号分隔。不使用 EasyTier 就不要改 `CHANGE_ME`，安装脚本会保持服务关闭。

真实密码哈希和 EasyTier 密钥不会作为 Nix 配置值求值，因此不会进入公开仓库，也不会复制进所有本机用户可读的 Nix store。

> ⚠️ 如果跳过这步，装好后**无法登录**！

#### A-3：确认你的机器类型

你是台式机还是笔记本？

- **台式机**（i5-13600KF + RTX 4070S）→ 用 `HAO_DESKTOP`
- **笔记本**（i7-8750H + GTX 1060）→ 用 `HAO_OFFLINE`
- 都不是？先根据实际显卡、处理器和磁盘控制器修改硬件配置，不要盲选。

#### A-4：自动分区（一条命令搞定）

```bash
sudo nix run .#disko -- \
  --mode disko hosts/HAO_DESKTOP/disko-config.nix
```

> 🔴 这条命令会**清空整块硬盘**。确认硬盘上没有重要数据再执行！

如果报错 `/dev/nvme0n1` 不存在，说明你的硬盘不叫这个名字。用 `lsblk` 看一下实际名字，然后改 disko 文件：

```bash
nano hosts/HAO_DESKTOP/disko-config.nix
```

把第 11 行的 `/dev/nvme0n1` 改成你实际看到的硬盘名字（比如 `/dev/sda`），保存退出（`Ctrl+O` → 回车 → `Ctrl+X`），再重新执行上面的 `sudo nix run ...` 命令。

分区成功后，硬盘已经被挂载到 `/mnt`。

#### A-5：核对硬件配置

`HAO_OFFLINE` 和 `HAO_DESKTOP` 都已带按磁盘 label 编写、由 Git 跟踪的硬件配置。
如果实际磁盘控制器不是普通 NVMe/AHCI，先运行 `sudo nixos-generate-config --root /mnt`
对照生成文件中的 `boot.initrd.availableKernelModules`，把缺少的模块补进对应
`hosts/<机器名>/hardware-configuration.nix`。不要直接覆盖已跟踪的文件系统布局。

#### A-6：安装系统

```bash
# 将暂存密钥安装到目标系统；目录权限为 0700，文件权限为 0600
sudo bash scripts/install-secrets.sh /mnt

sudo nixos-install --no-root-passwd --flake .#HAO_DESKTOP
```

> 把 `HAO_DESKTOP` 换成你实际的机器名（见 A-3）。

这条命令会开始下载和安装。耗时取决于网络、软件包大小和是否需要编译，屏幕上会滚动很多文字。

- 看到满屏文字在跑 → 正常，等着
- 停在同一行很久 → 也在下载，别急
- 屏幕偶尔出现方块乱码 → 不影响，继续等
- 安装完成后请使用前面写入 secrets 文件的 `admin` 用户密码登录；root 已按配置锁定，不应依赖 root 密码登录

看到 `安装完成` 或类似的提示后，输入：

```bash
sudo reboot
```

电脑重启后**立刻拔掉 U 盘**。如果能进图形登录界面 → 🎉 安装成功！

---

### 🅱️ 方案 B：双系统（保留 Windows）

> ⚠️ 双系统比单系统多几步，别慌，跟着做就行。

#### 在开始之前——在 Windows 里做的事

1. **备份重要文件**（万一操作失误，至少数据安全）
2. **给 NixOS 腾空间**：
   - 右键「此电脑」→「管理」→「磁盘管理」
   - 右键 C 盘 →「压缩卷」
   - 输入要腾出的空间大小，**至少 200GB**（输入 204800）
   - 点「压缩」，完成后会看到一块黑色的「未分配」空间
3. **关闭快速启动**：
   - 控制面板 → 电源选项 → 选择电源按钮的功能
   - 点「更改当前不可用的设置」
   - 取消勾选「启用快速启动」→ 保存

#### B-1：进入 NixOS 安装环境

按前面第三部分的步骤从 U 盘启动，进桌面开终端。

#### B-2：看看分区长什么样

```bash
lsblk
```

你应该看到类似这样的输出（**你的分区号可能不同**）：

```
nvme0n1          ← 整块硬盘
├─nvme0n1p1      ← EFI 分区（FAT32，200-500MB）
├─nvme0n1p2      ← Windows C 盘（NTFS，很大）
├─nvme0n1p3      ← Windows 恢复分区
└─空出来的空间     ← 刚才你在 Windows 里压缩出来的
```

> 💡 记住你压缩出来的是第几个分区（通常是 `p3`、`p4` 或 `p5`），后面要用。


> ⚠️ **国内网络注意**：如果 `git clone` 连不上 GitHub，回到上面 [方案 A 的 A-1 步骤](#a-1下载本仓库) 看三种解决方法。
#### B-3：下载本仓库


```bash
nix-shell -p git
git clone --branch main https://github.com/accoutmissing/HAO_OFFLINE_NIX.git
cd HAO_OFFLINE_NIX
```

#### B-4：设置登录密码

和方案 A 的 A-2 步骤完全一样：运行 `scripts/setup.sh`，再用 `mkpasswd -m yescrypt > secrets/admin-password-hash` 生成密码哈希。

#### B-5：手动创建 NixOS 分区

假设空出来的空间在 `/dev/nvme0n1` 上，是最后一个分区号（这里用 `p5` 举例，**以你 `lsblk` 实际看到的为准**）：

```bash
# 创建 Btrfs 分区——起止点必须按你 lsblk 看到的“实际空闲区间”填！
# ⚠️ 不要照抄下面的数字，这是示例：假设磁盘 500GB，Windows 占前 300GB
#    （约 0~300GB），恢复分区在末尾（约 480~500GB），空闲区就是 300~480GB。
#    下面的 mkfs 里 p5 也要换成 lsblk 显示的实际分区号。
# 🔴 起点数字不要写进 Windows 分区范围内！拿不准就用 Windows 的磁盘管理确认。
sudo parted /dev/nvme0n1 -- mkpart NIXOS btrfs 300GiB 480GiB

# 格式化，取名叫 NIXOS
sudo mkfs.btrfs -L NIXOS /dev/nvme0n1p5

# 挂载 + 创建子卷
sudo mount /dev/nvme0n1p5 /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo umount /mnt

# 重新挂载（让 @ 成为根目录）
sudo mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p5 /mnt
sudo mkdir -p /mnt/{boot,home}
sudo mount /dev/nvme0n1p1 /mnt/boot     # EFI 分区——和 Windows 共享
sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p5 /mnt/home
```

> 🔴 上面的 `nvme0n1p1` 和 `nvme0n1p5` 要根据你 `lsblk` 看到的实际编号来。EFI 分区一般是第一个分区（`p1`），NixOS 是你刚才创建的那个。

#### B-6：生成硬件配置

```bash
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix hosts/HAO_DESKTOP/
# 生成文件未被 git 跟踪时，flake 看不到它；强制加入索引
sudo git add -f hosts/HAO_DESKTOP/hardware-configuration.nix
```

#### B-7：修复 /boot 路径（如果需要）

双系统时，EFI 分区的 label 可能不是 `BOOT` 而是 `SYSTEM`（Windows 起的名字）：

```bash
lsblk -o NAME,LABEL /dev/nvme0n1p1
```

如果 LABEL 不是 `BOOT`，需要改硬件配置：

```bash
nano hosts/HAO_DESKTOP/hardware-configuration.nix
```

找到 `/boot` 那一段，把 `device = "/dev/disk/by-label/BOOT"` 改成 `device = "/dev/nvme0n1p1"`（用实际路径），保存退出。

#### B-8：安装系统

```bash
sudo bash scripts/install-secrets.sh /mnt
sudo nixos-install --no-root-passwd --flake .#HAO_DESKTOP
```

等待安装完成后重启；登录时使用前面配置的 `admin` 用户密码：

```bash
sudo reboot
```

**拔掉 U 盘**。重启后你会看到一个启动菜单（systemd-boot），用方向键选择：
- `NixOS` → 进 NixOS
- `Windows Boot Manager` → 进 Windows

> 🎉 恭喜，双系统搞定！

---

## 六、服务器 HAO_SERVER — 部署（HAO_SERVER 分支）

> 服务器配置在 **HAO_SERVER** 分支上维护，与桌面 main 分支隔离。

### 适用场景

- 家庭服务器 / NAS（本机长期运行）
- VPS 云服务器（公网，含 fail2ban 防爆破）

### 特性

| 模块 | 功能 |
|------|------|
| hardening | fail2ban + 防火墙默认拒绝 + 内核 sysctl 加固 |
| easytier | P2P 组网（密钥缺失自动关闭） |
| containers | Podman + lazydocker |
| auto-upgrade | 每周自动更新 + 14 天 GC |
| zram | 低内存 VPS 防 OOM |

### 部署

```bash
# 服务器上（用 HAO_SERVER 分支）
git clone -b HAO_SERVER https://github.com/accoutmissing/HAO_OFFLINE_NIX.git /etc/nixos
cd /etc/nixos

# 1. 填入密码哈希 + EasyTier 密钥（必做）
#    bash scripts/setup.sh（复制 secrets 模板）
#    mkpasswd -m yescrypt 生成后写入 vars/secrets.nix 的 initialHashedPassword
#    同一文件里填好 EasyTier 密钥与 peers

# 2. 生成硬件配置并强制跟踪
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix hosts/HAO_SERVER/
sudo git add -f hosts/HAO_SERVER/hardware-configuration.nix

# 3. 安装
sudo --preserve-env=HAO_SECRETS_FILE nixos-install --impure --flake .#HAO_SERVER
```

### 日常更新（或等自动更新）

```bash
sudo --preserve-env=HAO_SECRETS_FILE nixos-rebuild switch --impure --flake .#HAO_SERVER
```

---

## 七、装好之后干嘛

### 登录

启动后会看到一个图形登录界面（ReGreet），输入你之前用 `mkpasswd` 设置的密码，回车。进入桌面后，你会看到：

- 顶部一条状态栏（时钟、音量、电池、网络）
- 底部一个自动隐藏的 Dock（放常用软件）
- 按 `Mod+空格键`（Mod 就是 Windows 键）打开启动器

### 先把配置拉到本地

打开终端（启动器里搜 "kitty" 或 "terminal"），运行：

下面会自动保留本机硬件配置。若修改过其他模块，也要在构建前迁入新目录。

```bash
# 在新目录准备仓库，保留本机硬件配置；准备失败时原配置仍可用
(
  set -e
  HOST_CONFIG=HAO_DESKTOP # 笔记本改成 HAO_OFFLINE
  BACKUP_DIR="/etc/nixos.installer-backup-$(date +%Y%m%d-%H%M%S)"
  NEXT_DIR="$(sudo mktemp -d /etc/nixos-upstream.XXXXXX)"
  sudo git clone --branch main https://github.com/accoutmissing/HAO_OFFLINE_NIX.git "$NEXT_DIR"
  sudo chmod 0755 "$NEXT_DIR"
  sudo cp -a "/etc/nixos/hosts/$HOST_CONFIG/hardware-configuration.nix" \
    "$NEXT_DIR/hosts/$HOST_CONFIG/hardware-configuration.nix"
  sudo git -C "$NEXT_DIR" add "hosts/$HOST_CONFIG/hardware-configuration.nix"
  # 如有其他本机修改，在这里迁入 NEXT_DIR 后再继续
  sudo nixos-rebuild build --flake "$NEXT_DIR#$HOST_CONFIG"
  sudo mv /etc/nixos "$BACKUP_DIR"
  sudo mv "$NEXT_DIR" /etc/nixos
)
cd /etc/nixos
```

硬件配置必须保留本机的分区路径、EFI 设置和驱动，尤其是双系统；仓库模板不能
直接替代它。若还修改过其他模块，先把这些修改迁入 `NEXT_DIR`，再执行构建与
替换步骤。确认新配置能重建且重启正常后，再处理带时间戳的备份。

### 日常使用

| 你想干嘛 | 怎么做 |
|---------|--------|
| 打开软件 | 按 `Win + 空格`，输入软件名，回车 |
| 调音量 | 键盘上的音量键 / 右上角状态栏点音量图标 |
| 调亮度 | 键盘上的亮度键 |
| 锁屏 | 按 `Win + Alt + L` |
| 连 WiFi | 右上角状态栏点网络图标 |
| 截图 | 按 `Print Screen` 键 |
| 呼出 AI Agent | 按 `Win + Shift + Ctrl + A`，再次按下可隐藏且不丢失会话 |
| 关机 | 终端输入 `sudo poweroff`，或右上角菜单里有关机选项 |

第一次使用 AI Agent 时，打开终端并登录你要使用的服务：

```bash
codex login
claude # 首次启动时按提示登录
opencode auth login
```

系统默认打开 Codex。运行 `ai-pick` 可以临时选择其他 Agent；运行 `hao-agent --set claude` 可以把 Claude Code 设为默认。登录凭据只保存在当前用户目录，不会进入公开仓库。

### 更新系统

以后拉取最新配置并更新系统：

```bash
cd /etc/nixos
sudo git pull --ff-only
sudo nixos-rebuild switch --flake .#HAO_DESKTOP # 笔记本用 HAO_OFFLINE
```

如果更新与本机硬件配置冲突，先合并并保留本机分区和驱动设置，再重建；不要用
仓库模板覆盖这些设置。

### 清理垃圾（释放空间）

NixOS 每次更新会保留旧版本，时间长了占空间。定期清理：

```bash
sudo nix-collect-garbage --delete-older-than 7d
```

---

## 八、常见问题

### ❓ 终端是什么？我怎么打开它？

终端就是一个写命令的黑窗口。安装环境里桌面左下角找「终端」图标点开就行。

### ❓ 命令输错了怎么办？

按 `Ctrl+C` 终止当前命令，重新输。或者按方向键 `↑` 调出上一条命令修改。

### ❓ 复制粘贴在终端里怎么用？

- 复制：`Ctrl + Shift + C`
- 粘贴：`Ctrl + Shift + V`

### ❓ 安装到一半想重来？

```bash
# 卸载 /mnt
sudo umount -R /mnt
# 然后从分区那步重新开始
```

### ❓ lsblk 输出太多看不懂

使用 `lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS`，同时核对容量、型号、接口和挂载点。容量大小不能判断哪块盘可以清空；不要靠“最大的那个”或设备编号猜测。

### ❓ 装完后启动黑屏

1. 确认拔掉了 U 盘
2. 如果是双系统，检查 EFI 分区路径是否正确（B-7 步）
3. 如果是 Hyper-V 虚拟机，确认安全启动已关闭

### ❓ 装完后桌面上什么都没有

正常！这个桌面（Niri）是极简风格，顶部有状态栏，底部 Dock 是自动隐藏的（鼠标移到底部会浮出来）。按 `Win + 空格` 打开启动器。

### ❓ 我想装更多软件

在 `/etc/nixos` 目录下编辑配置文件（`modules/nixos/desktop/packages.nix`），在 `environment.systemPackages` 列表里加上你想要软件的包名，然后运行 `sudo nixos-rebuild switch --flake .#你的主机名`。

去 https://search.nixos.org/packages 搜索你想要的软件包名。

### ❓ 装完后发现分区太小了

分区大小装好后就很难改了。建议至少给 NixOS 分 200GB。

---

## 九、还有问题？

- **GitHub Issues**：https://github.com/accoutmissing/HAO_OFFLINE_NIX/issues
- **NixOS 中文社区**：搜 "NixOS 中文" 找相关讨论群

> 💡 记住：遇到问题先看报错信息，把报错信息复制下来去搜索引擎搜一下，大概率别人也遇到过。

---

> 这篇指南写给你的——一个可能从来没碰过 Linux 的人。NixOS 的学习曲线确实陡，但装好之后你会发现它的好：重装系统不再是一场噩梦，换电脑只需要一个 U 盘 + 一行命令。


