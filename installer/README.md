# HAO Installer

HAO Installer 是基于 NixOS minimal installation CD 的全屏键盘安装器。它参考
Omarchy 的开箱即用路径，但安装目标仍完全由本仓库的 Flake、Disko 和主机模块定义。

## 当前范围

- UEFI 启动。
- `HAO_DESKTOP` 与 `HAO_OFFLINE` 两个硬件配置。
- 仅支持整盘安装，最小目标磁盘 64 GiB。
- GPT、512 MiB ESP、Btrfs `@` 与 `@home` 子卷。
- 安装前显示磁盘路径、容量和型号，并要求输入 `ERASE <磁盘名>`。
- 无法唯一识别安装介质时停止；擦盘前再次确认目标磁盘身份。
- 默认以 Cage + Kitty 显示中文向导，显卡无法启动图形界面时退回英文 VT；维修终端仍保留在 tty2。
- 联网版清盘前完整构建所选主机系统；离线版提前装入匹配机型的系统闭包，安装现场只做校验和复制，不需联网下载或把完整系统写入内存盘。
- 所有镜像均携带锁定的直接与间接 Flake 输入源码。联网版并行检测可用缓存，显式设置国内缓存优先级，并排除本次检测失败的源。
- 清盘前确认系统闭包有效、目标磁盘身份未变，并检查系统占用加 8 GiB 余量是否能放入目标盘。
- ISO 预置 Mihomo（Clash 核心）、常用 GeoIP/GeoSite 数据和 LocalSend；向导可在临时图形窗口接收配置，并将本地代理同时用于 Nix daemon。LocalSend 所需的 TCP/UDP 53317 已在安装环境开放。
- 登录密码转换为 yescrypt 哈希后写入目标系统的
  `/var/lib/hao-secrets/admin-password-hash`，不会进入 Git 或 Nix store。
- 安装日志持久化为 `/var/log/hao-install.log`。

双系统暂不进入图形化路径。需要保留 Windows 时，继续按
[`INSTALL_GUIDE.md`](../INSTALL_GUIDE.md) 的高级手动流程操作。

## 构建

```bash
nix build --accept-flake-config .#hao-installer-iso

# 国内使用优先选与机型相符的离线版，体积更大
nix build --accept-flake-config .#hao-installer-offline-desktop-iso
nix build --accept-flake-config .#hao-installer-offline-laptop-iso
```

镜像位于 `result/iso/`。GitHub Actions 的 `build-installer-iso` 工作流也可以手动
构建；发布 Release 时会自动把 ISO 和 `SHA256SUMS` 附加到 Release。

`build-offline-installer` 工作流可手动选择 desktop、laptop 或两者。超过 2 GiB 的镜像拆成 1900 MiB 分卷，附完整 ISO 和分卷的校验值，以及 Windows 合并工具。该工作流生成候选产物，发布前仍需核对提交与产物，不自动覆盖已有 Release。

## 安装阶段

1. 验证离线闭包，或使用锁定的 Flake 输入完整构建所选主机系统，并保留结果与 GC root。
2. 再次确认目标磁盘，执行镜像内预构建的 Disko 脚本完成分区、格式化和挂载；分区阶段无需临时构建工具。
3. 把当前发布版本的配置复制到可编辑的 `/mnt/etc/nixos`。
4. 安装 root-only 密码哈希并保留已保存的 Wi-Fi 连接；两台主机的硬件配置均已纳入仓库版本控制。
5. 用 `nixos-install --system` 安装第 1 步准备好的同一系统，避免清盘后再次求值、构建或访问 GitHub。
6. 同步磁盘，保存日志并显示重启页。

tty1 由安装器独占；遇到问题可使用 `Ctrl+Alt+F2` 切换到维修终端。
联网、代理配置导入及下载检查步骤见 [`INSTALL_GUIDE.md`](../INSTALL_GUIDE.md)。

下载/构建和系统安装阶段可重试，也可回到联网菜单后继续；分区阶段不会自动重复执行。临时代理只存在于 live 环境，不自动带入目标系统。

实现依据：[Nix fetchTree 对已有 narHash 源码的复用](https://nix.dev/manual/nix/2.33/language/builtins.html#builtins-fetchTree)、[USTC 动态缓存及回退说明](https://mirrors.ustc.edu.cn/help/nix-channels.html)。CI 包含缓存/代理回归检查，以及中文界面与最小测试系统的虚拟机离线安装检查；这些检查不替代两台真实硬件的启动和安装验收。
