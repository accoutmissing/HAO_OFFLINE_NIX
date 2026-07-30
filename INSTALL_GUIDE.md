# 🐣 NixOS 安装入门指南 — 写给从零开始的小白

> **别怕，这篇指南假设你完全不懂 Linux。**  
> 不用懂命令行，不用懂分区，不用懂编程。跟着一步步来就能装好。

---

## 一、先搞清楚：NixOS 是什么？我为什么要装它？

- **NixOS 是一个操作系统**，就像你熟悉的 Windows 一样，装了它你的电脑就能用。
- 它和 Windows 最大的区别是：**装软件、改设置全部写在配置文件里**，以后换电脑或者重装系统，拿同一个配置文件一跑，所有软件、所有设置全部恢复，一模一样。
- 本仓库就是一套已经配好的配置文件——装上去直接就是**中文输入法 + 游戏 + 开发环境 + 好看的桌面**，不用自己折腾。

**简单来说：装一次，配置文件留着，以后再也不怕重装。**

---

## 二、安装前你要准备什么

### 硬件清单

| 东西 | 说明 |
|------|------|
| 💻 一台要装 NixOS 的电脑 | 台式机或笔记本都行 |
| 💾 一个 **8GB 以上**的 U 盘 | 会被清空，先备份里面重要文件 |
| 🌐 能上网的网络 | 安装全程在线，最好插网线 |

### 下载两个东西

**1. NixOS 系统镜像（ISO 文件）**

这是 NixOS 的"安装盘"，大约 2-3GB。

- 打开浏览器，访问：**https://mirrors.tuna.tsinghua.edu.cn/nixos-images/**
- 往下翻，找到最新日期那个文件夹，点进去
- 下载文件名里带 **`gnome`** 和 **`x86_64-linux`** 的 `.iso` 文件
  - 例如：`nixos-gnome-25.05.xxxx.xxxx-x86_64-linux.iso`
- GNOME 版本带图形界面，对新手友好

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
5. 弹窗问写入模式，选「以 ISO 镜像模式写入」，确定
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
git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git
cd HAO_OFFLINE_NIX
```

#### A-2：设置你的登录密码

装好系统后，你需要一个密码才能登录桌面。现在就设好：

```bash
mkpasswd -m yescrypt
```

- 输入你想要的密码（**输入时屏幕不会显示任何东西，这是正常的**）
- 输入两次后，屏幕上会出现一串以 `$y$` 开头的乱码——**把它复制下来**
- 然后编辑配置文件：

```bash
nano vars/default.nix
```

- 用方向键往下移动，找到这一行：
  ```
  initialHashedPassword = null;
  ```
- 把 `null` 替换成你刚才复制的那个 `$y$...` 乱码（**用引号包起来**）
  ```
  initialHashedPassword = "$y$j9T...你复制的乱码...";
  ```
- 按 `Ctrl+O` → 回车（保存），再按 `Ctrl+X`（退出）

> ⚠️ 如果跳过这步，装好后**无法登录**！

#### A-3：确认你的机器类型

你是台式机还是笔记本？

- **台式机**（i5-13600KF + RTX 4070S）→ 用 `HAO_DESKTOP`
- **笔记本**（i7-8750H + GTX 1060）→ 用 `HAO_OFFLINE`
- 都不是？选 `HAO_DESKTOP`，装好后可以改

#### A-4：自动分区（一条命令搞定）

```bash
sudo nix run github:accoutmissing/HAO_OFFLINE_NIX#disko -- \
  --mode disko hosts/HAO_DESKTOP/disko-config.nix
```

> 🔴 这条命令会**清空整块硬盘**。确认硬盘上没有重要数据再执行！

如果报错 `/dev/nvme0n1` 不存在，说明你的硬盘不叫这个名字。用 `lsblk` 看一下实际名字，然后改 disko 文件：

```bash
nano hosts/HAO_DESKTOP/disko-config.nix
```

把第 11 行的 `/dev/nvme0n1` 改成你实际看到的硬盘名字（比如 `/dev/sda`），保存退出（`Ctrl+O` → 回车 → `Ctrl+X`），再重新执行上面的 `sudo nix run ...` 命令。

分区成功后，硬盘已经被挂载到 `/mnt`。

#### A-5：生成硬件配置（笔记本必做，台式机可跳过）

如果你选择 `HAO_OFFLINE`（笔记本），安装前先生成并加入 flake：

```bash
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix hosts/HAO_OFFLINE/
# git 仓库型 flake 看不到被 .gitignore 排除的文件，必须强制加入索引
sudo git add -f hosts/HAO_OFFLINE/hardware-configuration.nix
```

台式机 `HAO_DESKTOP` 已带按磁盘 label 编写的硬件配置，可以直接进入下一步。

#### A-6：安装系统

```bash
sudo nixos-install --flake .#HAO_DESKTOP
```

> 把 `HAO_DESKTOP` 换成你实际的机器名（见 A-3）。

这条命令会开始下载和安装。**第一次安装需要 10-30 分钟**，屏幕上会滚动很多文字，这是正常的。

- 看到满屏文字在跑 → 正常，等着
- 停在同一行很久 → 也在下载，别急
- 屏幕偶尔出现方块乱码 → 不影响，继续等
- 最后会提示你设置 root 密码 → 输入一个密码（记好！），回车

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
git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git
cd HAO_OFFLINE_NIX
```

#### B-4：设置登录密码

和方案 A 的 A-2 步骤完全一样：用 `mkpasswd -m yescrypt` 生成密码，写入 `vars/default.nix`。

#### B-5：手动创建 NixOS 分区

假设空出来的空间在 `/dev/nvme0n1` 上，是最后一个分区号（这里用 `p5` 举例，**以你 `lsblk` 实际看到的为准**）：

```bash
# 创建 Btrfs 分区（用掉剩下的所有空间）
sudo parted /dev/nvme0n1 -- mkpart primary btrfs 50% 100%

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
sudo nixos-install --flake .#HAO_DESKTOP
```

等 10-30 分钟，提示输入 root 密码后，重启：

```bash
sudo reboot
```

**拔掉 U 盘**。重启后你会看到一个启动菜单（systemd-boot），用方向键选择：
- `NixOS` → 进 NixOS
- `Windows Boot Manager` → 进 Windows

> 🎉 恭喜，双系统搞定！

---

## 六、装好之后干嘛

### 登录

启动后会看到一个图形登录界面（ReGreet），输入你之前用 `mkpasswd` 设置的密码，回车。进入桌面后，你会看到：

- 顶部一条状态栏（时钟、音量、电池、网络）
- 底部一个自动隐藏的 Dock（放常用软件）
- 按 `Mod+空格键`（Mod 就是 Windows 键）打开启动器

### 先把配置拉到本地

打开终端（启动器里搜 "kitty" 或 "terminal"），运行：

```bash
sudo git clone https://github.com/accoutmissing/HAO_OFFLINE_NIX.git /etc/nixos
cd /etc/nixos
```

以后所有修改都在 `/etc/nixos` 里做。

### 日常使用

| 你想干嘛 | 怎么做 |
|---------|--------|
| 打开软件 | 按 `Win + 空格`，输入软件名，回车 |
| 调音量 | 键盘上的音量键 / 右上角状态栏点音量图标 |
| 调亮度 | 键盘上的亮度键 |
| 锁屏 | 按 `Win + L` |
| 连 WiFi | 右上角状态栏点网络图标 |
| 截图 | 按 `Print Screen` 键 |
| 关机 | 终端输入 `sudo reboot`，或右上角菜单里有关机选项 |

### 更新系统

以后我更新了配置，你拉取最新版本更新系统只要两行：

```bash
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#HAO_DESKTOP
```

### 清理垃圾（释放空间）

NixOS 每次更新会保留旧版本，时间长了占空间。定期清理：

```bash
sudo nix-collect-garbage --delete-older-than 7d
```

---

## 七、常见问题

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

只看 `NAME` 和 `SIZE` 列就够了。**容量最大那个**就是你的硬盘（通常是 `nvme0n1` 或 `sda`），14-16GB 大小的那个是 U 盘。

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

## 八、还有问题？

- **GitHub Issues**：https://github.com/accoutmissing/HAO_OFFLINE_NIX/issues
- **NixOS 中文社区**：搜 "NixOS 中文" 找相关讨论群

> 💡 记住：遇到问题先看报错信息，把报错信息复制下来去搜索引擎搜一下，大概率别人也遇到过。

---

> 这篇指南写给你的——一个可能从来没碰过 Linux 的人。NixOS 的学习曲线确实陡，但装好之后你会发现它的好：重装系统不再是一场噩梦，换电脑只需要一个 U 盘 + 一行命令。

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

## 八、还有问题？

- **GitHub Issues**：https://github.com/accoutmissing/HAO_OFFLINE_NIX/issues
- **NixOS 中文社区**：搜 "NixOS 中文" 找相关讨论群

> 记住：遇到问题先看报错信息，把报错信息复制下来去搜索引擎搜一下，大概率别人也遇到过。

---

> 这篇指南写给你的——一个可能从来没碰过 Linux 的人。NixOS 的学习曲线确实陡，但装好之后你会发现它的好：重装系统不再是一场噩梦，换电脑只需要一个 U 盘 + 一行命令。
