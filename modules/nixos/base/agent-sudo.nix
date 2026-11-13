_:
{
  # ── Agent 免密 sudo（A 方案） ───────────────────────────────────────
  # 以 admin 身份运行的本机 AI Agent 可直接执行任意 sudo 命令，
  # 等价于 root 权限。任何能以 admin 登录的途径同样享有该权限。
  # 撤销：删除本文件后重建系统。
  security.sudo.wheelNeedsPassword = false;
}
