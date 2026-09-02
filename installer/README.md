# HAO Installer

HAO Installer 是基于 NixOS minimal installation CD 的全屏键盘安装器。它参考
Omarchy 的开箱即用路径，但安装目标仍完全由本仓库的 Flake、Disko 和主机模块定义。

## 当前范围

- UEFI 启动。
- `HAO_DESKTOP` 与 `HAO_OFFLINE` 两个硬件配置。
- 仅支持整盘安装，最小目标磁盘 64 GiB。
- GPT、512 MiB ESP、Btrfs `@` 与 `@home` 子卷。
- 安装前显示磁盘路径、容量和型号，并要求输入 `ERASE <磁盘名>`。
- 登录密码转换为 yescrypt 哈希后写入目标系统的
  `/var/lib/hao-secrets/admin-password-hash`，不会进入 Git 或 Nix store。
- 安装日志持久化为 `/var/log/hao-install.log`。

双系统暂不进入图形化路径。需要保留 Windows 时，继续按
[`INSTALL_GUIDE.md`](../INSTALL_GUIDE.md) 的高级手动流程操作。

## 构建

```bash
nix build --accept-flake-config .#hao-installer-iso
```

镜像位于 `result/iso/`。GitHub Actions 的 `build-installer-iso` 工作流也可以手动
构建；发布 Release 时会自动把 ISO 和 `SHA256SUMS` 附加到 Release。

## 安装阶段

1. 检查锁定的 Flake 输入。
2. 再次确认目标磁盘并由 Disko 清盘、分区、格式化和挂载。
3. 把当前发布版本的配置复制到 `/mnt/etc/nixos`。
4. 生成本机硬件配置并安装 root-only 密码哈希。
5. 运行 `nixos-install`。
6. 同步磁盘，保存日志并显示重启页。

tty1 由安装器独占；遇到问题可使用 `Ctrl+Alt+F2` 切换到维修终端。
