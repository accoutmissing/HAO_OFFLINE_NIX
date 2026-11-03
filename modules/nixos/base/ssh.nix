_:
{
  # 启用 SSH（远程管理与部署用）
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # 键盘交互式认证会绕过 PasswordAuthentication=false。
      KbdInteractiveAuthentication = false;
    };
  };
}
